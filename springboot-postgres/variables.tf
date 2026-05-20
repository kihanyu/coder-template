# ==========================================
# 1. Coder 기본 인프라 설정 관련 변수
# ==========================================

variable "architecture" {
  type        = string
  description = "컨테이너가 실행될 호스트 아키텍처 (amd64 또는 arm64)"
  default     = "amd64"
}

# ==========================================
# 2. Spring Boot (Java) 개발 환경 관련 변수
# ==========================================

variable "java_version" {
  type        = string
  description = "개발 환경에 설치할 기본 JDK 버전 (Spring Boot 4.x 대응을 위해 JDK 21 이상 권장)"
  default     = "21"
}

# ==========================================
# 3. PostgreSQL 데이터베이스 계정 및 연결 변수
# ==========================================

variable "db_user" {
  type        = string
  description = "PostgreSQL 데이터베이스 마스터 사용자 계정명"
  default     = "shiloh"
}

variable "db_password" {
  type        = string
  description = "PostgreSQL 데이터베이스 마스터 비밀번호"
  default     = "devpass"
  sensitive   = true # Coder CLI나 로그에 비밀번호가 노출되는 것을 방지
}

variable "db_name" {
  type        = string
  description = "초기 생성할 기본 데이터베이스 스키마 이름"
  default     = "appdb"
}

# ==========================================
# 4. pgAdmin (Web DB GUI) 계정 변수
# ==========================================

variable "pgadmin_email" {
  type        = string
  description = "pgAdmin 웹 대시보드 로그인용 관리자 이메일"
  default     = "admin@coder.local"
}

variable "pgadmin_password" {
  type        = string
  description = "pgAdmin 웹 대시보드 로그인용 비밀번호"
  default     = "adminpass"
  sensitive   = true
}