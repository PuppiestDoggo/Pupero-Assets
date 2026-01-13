#!/usr/bin/env bash
#
# Pupero Deployment Script
# This script clones/fetches all GitHub repositories and pulls all Docker images
#
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory (project root)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# GitHub organization
GITHUB_ORG="PuppiestDoggo"

# All Pupero repositories
REPOS=(
    "Pupero-AdminAPI"
    "Pupero-APIManager"
    "Pupero-Assets"
    "Pupero-CreateDB"
    "Pupero-LoginBackend"
    "Pupero-LoginFrontEnd"
    "Pupero-Matrix"
    "Pupero-Moderation"
    "Pupero-monerod"
    "Pupero-MoneroWalletManager"
    "Pupero-Offers"
    "Pupero-Sweeper"
    "Pupero-WalletManagerDB"
)

# Custom Pupero Docker images
PUPERO_IMAGES=(
    "blackmine57/pupero-api-manager:latest"
    "blackmine57/pupero-login:latest"
    "blackmine57/pupero-moderation:latest"
    "blackmine57/pupero-offers:latest"
    "blackmine57/pupero-transactions:latest"
    "blackmine57/pupero-walletmanager:latest"
    "blackmine57/pupero-database:latest"
    "blackmine57/pupero-flask:latest"
    "blackmine57/pupero-sweeper:latest"
    "blackmine57/pupero-admin:latest"
    "blackmine57/pupero-monerod:latest"
    "blackmine57/explorer:latest"
)

# External Docker images
EXTERNAL_IMAGES=(
    "rabbitmq:3.13-management"
    "postgres:16"
    "matrixdotorg/synapse:latest"
    "vectorim/element-web:latest"
    "docker.elastic.co/elasticsearch/elasticsearch:8.14.3"
    "docker.elastic.co/kibana/kibana:8.14.3"
    "docker.elastic.co/logstash/logstash:8.14.3"
    "docker.elastic.co/beats/filebeat:8.14.3"
    "grafana/grafana:10.4.6"
    "prom/prometheus:v2.53.0"
    "quay.io/prometheuscommunity/elasticsearch-exporter:latest"
    "curlimages/curl:8.10.1"
)

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Print banner
print_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                  PUPERO DEPLOYMENT SCRIPT                    ║"
    echo "║                                                              ║"
    echo "║  This script will:                                          ║"
    echo "║  1. Clone or fetch all GitHub repositories                  ║"
    echo "║  2. Pull all Docker images                                  ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v git &> /dev/null; then
        log_error "git is not installed. Please install git first."
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        log_error "docker is not installed. Please install docker first."
        exit 1
    fi
    
    log_success "All prerequisites met."
}

# Clone or fetch a repository
clone_or_fetch_repo() {
    local repo_name="$1"
    local repo_dir="$SCRIPT_DIR/$repo_name"
    local ssh_url="git@github.com:${GITHUB_ORG}/${repo_name}.git"
    local https_url="https://github.com/${GITHUB_ORG}/${repo_name}.git"
    
    if [ -d "$repo_dir" ]; then
        log_info "Repository $repo_name exists, fetching updates..."
        if git -C "$repo_dir" fetch --all --prune 2>/dev/null; then
            # Try to pull if on a branch
            if git -C "$repo_dir" symbolic-ref -q HEAD &>/dev/null; then
                git -C "$repo_dir" pull --ff-only 2>/dev/null || true
            fi
            log_success "Fetched $repo_name"
        else
            log_warning "Failed to fetch $repo_name (may have no remote or network issues)"
        fi
    else
        log_info "Cloning $repo_name..."
        # Try SSH first, fall back to HTTPS
        if git clone "$ssh_url" "$repo_dir" 2>/dev/null; then
            log_success "Cloned $repo_name (SSH)"
        elif git clone "$https_url" "$repo_dir" 2>/dev/null; then
            log_success "Cloned $repo_name (HTTPS)"
        else
            log_error "Failed to clone $repo_name"
            return 1
        fi
    fi
    return 0
}

# Pull a Docker image
pull_docker_image() {
    local image="$1"
    log_info "Pulling $image..."
    if docker pull "$image" 2>/dev/null; then
        log_success "Pulled $image"
        return 0
    else
        log_warning "Failed to pull $image (may not exist yet or network issues)"
        return 1
    fi
}

# Main function for repositories
deploy_repos() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                    FETCHING REPOSITORIES                       ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local success_count=0
    local fail_count=0
    
    for repo in "${REPOS[@]}"; do
        if clone_or_fetch_repo "$repo"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    done
    
    echo ""
    log_info "Repositories: ${success_count} succeeded, ${fail_count} failed"
}

# Main function for Docker images
deploy_images() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                    PULLING DOCKER IMAGES                       ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local success_count=0
    local fail_count=0
    
    log_info "Pulling Pupero custom images..."
    echo ""
    for image in "${PUPERO_IMAGES[@]}"; do
        if pull_docker_image "$image"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    done
    
    echo ""
    log_info "Pulling external images..."
    echo ""
    for image in "${EXTERNAL_IMAGES[@]}"; do
        if pull_docker_image "$image"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    done
    
    echo ""
    log_info "Docker images: ${success_count} succeeded, ${fail_count} failed"
}

# Print usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -a, --all       Deploy everything (repos + images) [default]"
    echo "  -r, --repos     Only clone/fetch repositories"
    echo "  -i, --images    Only pull Docker images"
    echo "  -p, --pupero    Only pull Pupero custom images"
    echo "  -e, --external  Only pull external images"
    echo "  -h, --help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0              # Deploy everything"
    echo "  $0 --repos      # Only fetch/clone repos"
    echo "  $0 --images     # Only pull all Docker images"
    echo "  $0 --pupero     # Only pull Pupero images"
}

# Main entry point
main() {
    print_banner
    check_prerequisites
    
    local do_repos=false
    local do_pupero_images=false
    local do_external_images=false
    
    # Parse arguments
    if [ $# -eq 0 ]; then
        # Default: do everything
        do_repos=true
        do_pupero_images=true
        do_external_images=true
    else
        while [ $# -gt 0 ]; do
            case "$1" in
                -a|--all)
                    do_repos=true
                    do_pupero_images=true
                    do_external_images=true
                    ;;
                -r|--repos)
                    do_repos=true
                    ;;
                -i|--images)
                    do_pupero_images=true
                    do_external_images=true
                    ;;
                -p|--pupero)
                    do_pupero_images=true
                    ;;
                -e|--external)
                    do_external_images=true
                    ;;
                -h|--help)
                    usage
                    exit 0
                    ;;
                *)
                    log_error "Unknown option: $1"
                    usage
                    exit 1
                    ;;
            esac
            shift
        done
    fi
    
    # Execute selected operations
    if [ "$do_repos" = true ]; then
        deploy_repos
    fi
    
    if [ "$do_pupero_images" = true ] || [ "$do_external_images" = true ]; then
        echo ""
        echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${BLUE}                    PULLING DOCKER IMAGES                       ${NC}"
        echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        
        local success_count=0
        local fail_count=0
        
        if [ "$do_pupero_images" = true ]; then
            log_info "Pulling Pupero custom images..."
            echo ""
            for image in "${PUPERO_IMAGES[@]}"; do
                if pull_docker_image "$image"; then
                    ((success_count++))
                else
                    ((fail_count++))
                fi
            done
            echo ""
        fi
        
        if [ "$do_external_images" = true ]; then
            log_info "Pulling external images..."
            echo ""
            for image in "${EXTERNAL_IMAGES[@]}"; do
                if pull_docker_image "$image"; then
                    ((success_count++))
                else
                    ((fail_count++))
                fi
            done
            echo ""
        fi
        
        log_info "Docker images: ${success_count} succeeded, ${fail_count} failed"
    fi
    
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                    DEPLOYMENT COMPLETE                         ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    log_info "Next steps:"
    echo "  1. cd Pupero-Assets"
    echo "  2. cp .env.example .env  (if not already done)"
    echo "  3. Edit .env with your configuration"
    echo "  4. docker compose up -d"
    echo ""
}

# Run main
main "$@"
