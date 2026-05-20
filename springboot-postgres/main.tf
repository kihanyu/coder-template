terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 2.17.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 4.4.0"
    }
  }
}

# 1. Coder 현재 사용자 및 워크스페이스 메타데이터 가져오기
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# 2. 개별 개발자 전용 격리된 Docker 네트워크 생성
resource "docker_network" "private_network" {
  name = "coder-${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}-net"
}

# 3. 소스 코드 및 데이터 보존을 위한 Persistent 볼륨 정의
resource "docker_volume" "home_volume" {
  name = "coder-${data.coder_workspace.me.id}-home"
}

resource "docker_volume" "pg_data" {
  name = "coder-${data.coder_workspace.me.id}-pgdata"
}

# 4. Coder 에이전트 설정 (Spring Boot 환경 구축 및 구동 스크립트)
resource "coder_agent" "main" {
  os             = "linux"
  arch           = "amd64"
  api_key_scope = "all"
  startup_script = <<EOT
    #!/bin/bash
    echo "☕ JDK 25 및 개발 도구 환경 설치 중..."
    sudo apt-get update
    sudo apt-get install -y openjdk-25-jdk git curl unzip SDKMAN_DIR
    
    # SDKMAN을 활용한 모던 툴체인(Gradle/Maven) 관리
    curl -s "https://get.sdkman.io" | bash
    source "$HOME/.sdkman/bin/sdkman-init.sh"
    sdk install gradle
    
    echo "🚀 PostgreSQL 연결 대기 중..."
    until nc -z localhost 5432; do
      sleep 1
    done
    echo "✅ PostgreSQL 연결 성공!"

    # Spring Boot 예시 프로젝트가 없는 경우 가볍게 클론 (선택 사항)
    if [ ! -d "~/project" ]; then
      git clone https://github.com/spring-guides/gs-spring-boot.git ~/project
    fi
  EOT

  # JetBrains Gateway 또는 VS Code SSH 접속용 설정
  metadata {
    display_name = "Java Version"
    key          = "java"
    script       = "java --version | head -n 1"
    interval     = 60
  }
}

# 5. 메인 개발 컨테이너 (Spring Boot 구동부)
resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start ? 1 : 0
  image = "codercom/enterprise-base:ubuntu" # Coder 공식 베이스 이미지 (sudo 권한 포함)
  name  = "coder-${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}"
  
  networking_mode = "bridge"
  networks_advanced {
    name = docker_network.private_network.name
  }

  volumes {
    volume_name    = docker_volume.home_volume.name
    container_path = "/home/coder"
  }

  # Coder Agent를 컨테이너 내부에 주입
  env = ["CODER_AGENT_TOKEN=${coder_agent.main.token}"]
}

# 6. 사이드카(Sidecar) PostgreSQL 컨테이너
resource "docker_container" "postgres" {
  count = data.coder_workspace.me.start ? 1 : 0
  image = "postgres:16-alpine"
  name  = "coder-${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}-postgres"
  
  networks_advanced {
    name    = docker_network.private_network.name
    aliases = ["postgres-db"] # Spring Boot에서 컨테이너 내부 통신 시 사용할 호스트명
  }

  env = [
    "POSTGRES_USER=shiloh",
    "POSTGRES_PASSWORD=devpass",
    "POSTGRES_DB=appdb"
  ]

  volumes {
    volume_name    = docker_volume.pg_data.name
    container_path = "/var/lib/postgresql/data"
  }
}

# 7. 편리한 DB 관리를 위한 웹 기반 pgAdmin 사이드카
resource "docker_container" "pgadmin" {
  count = data.coder_workspace.me.start ? 1 : 0
  image = "dpage/pgadmin4:latest"
  name  = "coder-${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}-pgadmin"
  
  networks_advanced {
    name = docker_network.private_network.name
  }

  env = [
    "PGADMIN_DEFAULT_EMAIL=admin@coder.local",
    "PGADMIN_DEFAULT_PASSWORD=adminpass"
  ]
}

# 8. Coder 대시보드에 바로가기 앱 링크 추가
resource "coder_app" "pgadmin_link" {
  agent_id     = coder_agent.main.id
  slug         = "pgadmin"
  display_name = "pgAdmin (DB Web GUI)"
  url          = "http://localhost:80" # pgAdmin 내부 포트 링크 연동
  icon         = "https://www.pgadmin.org/favicon.ico"
}