#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Confirmation prompt
confirm_destruction() {
    print_warning "This will destroy your EKS cluster and all associated resources!"
    print_warning "This action cannot be undone."
    echo
    read -p "Are you sure you want to continue? Type 'yes' to confirm: " confirmation
    
    if [[ "$confirmation" != "yes" ]]; then
        print_status "Destruction cancelled."
        exit 0
    fi
}

# Clean up LoadBalancers that might prevent VPC deletion
cleanup_load_balancers() {
    print_status "Cleaning up LoadBalancers..."
    
    CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "")
    
    if [[ -n "$CLUSTER_NAME" ]]; then
        # Delete ingress resources that create ALBs
        kubectl delete ingress --all -n demo 2>/dev/null || true
        
        # Wait for LoadBalancers to be deleted
        print_status "Waiting for LoadBalancers to be cleaned up..."
        sleep 30
    fi
}

# Destroy infrastructure with Terraform
destroy_infrastructure() {
    print_status "Destroying infrastructure with Terraform..."
    
    # Try to clean up Kubernetes resources first
    cleanup_load_balancers
    
    # Run terraform destroy
    terraform destroy -auto-approve
    
    print_status "Infrastructure destroyed successfully!"
}

# Clean up kubectl configuration
cleanup_kubectl_config() {
    print_status "Cleaning up kubectl configuration..."
    
    CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "demo-eks-cluster")
    
    # Remove cluster context from kubeconfig
    kubectl config delete-context $CLUSTER_NAME 2>/dev/null || true
    kubectl config delete-cluster $CLUSTER_NAME 2>/dev/null || true
    kubectl config unset users.$CLUSTER_NAME 2>/dev/null || true
    
    print_status "kubectl configuration cleaned up."
}

# Optional: Remove kubectl-ai if installed locally
remove_kubectl_ai() {
    read -p "Do you want to remove kubectl-ai from your system? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if command -v kubectl-ai &> /dev/null; then
            if [[ "$OSTYPE" == "darwin"* ]] && command -v brew &> /dev/null; then
                brew uninstall kubectl-ai 2>/dev/null || true
            else
                sudo rm -f /usr/local/bin/kubectl-ai 2>/dev/null || true
            fi
            print_status "kubectl-ai removed."
        else
            print_status "kubectl-ai not found on system."
        fi
    fi
}

# Main execution
main() {
    print_status "Starting cleanup process..."
    echo
    
    confirm_destruction
    destroy_infrastructure
    cleanup_kubectl_config
    remove_kubectl_ai
    
    print_status "Cleanup completed successfully!"
    print_status "All AWS resources have been destroyed."
}

# Run main function
main "$@"