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

# Check if required tools are installed
check_dependencies() {
    print_status "Checking dependencies..."
    
    dependencies=("terraform" "aws" "kubectl")
    for cmd in "${dependencies[@]}"; do
        if ! command -v $cmd &> /dev/null; then
            print_error "$cmd is not installed. Please install it before continuing."
            exit 1
        fi
    done
    
    print_status "All dependencies are installed."
}

# Configure AWS credentials
configure_aws() {
    print_status "Checking AWS configuration..."
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_warning "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_status "AWS credentials are configured."
}

# Initialize and apply Terraform
deploy_infrastructure() {
    print_status "Initializing Terraform..."
    terraform init
    
    print_status "Validating Terraform configuration..."
    terraform validate
    
    print_status "Planning Terraform deployment..."
    terraform plan
    
    read -p "Do you want to apply this plan? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Applying Terraform configuration..."
        terraform apply -auto-approve
    else
        print_warning "Deployment cancelled."
        exit 1
    fi
}

# Configure kubectl
configure_kubectl() {
    print_status "Configuring kubectl..."
    
    CLUSTER_NAME=$(terraform output -raw cluster_name)
    REGION=$(terraform output -raw region)
    
    aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME
    
    print_status "Testing kubectl connection..."
    kubectl get nodes
}

# Install kubectl-ai locally (alternative to running in cluster)
install_kubectl_ai_locally() {
    print_status "Installing kubectl-ai locally..."
    
    # Check if kubectl-ai is already installed
    if command -v kubectl-ai &> /dev/null; then
        print_status "kubectl-ai is already installed."
        return
    fi
    
    # Install kubectl-ai using various methods
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        curl -Lo kubectl-ai https://github.com/sozercan/kubectl-ai/releases/latest/download/kubectl-ai-linux-amd64
        chmod +x kubectl-ai
        sudo mv kubectl-ai /usr/local/bin/
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install kubectl-ai
        else
            curl -Lo kubectl-ai https://github.com/sozercan/kubectl-ai/releases/latest/download/kubectl-ai-darwin-amd64
            chmod +x kubectl-ai
            sudo mv kubectl-ai /usr/local/bin/
        fi
    else
        print_warning "Unsupported OS. Please install kubectl-ai manually from https://github.com/sozercan/kubectl-ai"
        return
    fi
    
    print_status "kubectl-ai installed successfully!"
}

# Setup kubectl-ai configuration
setup_kubectl_ai() {
    print_status "Setting up kubectl-ai..."
    
    # Check if OpenAI API key is set
    if [[ -z "${OPENAI_API_KEY}" ]]; then
        print_warning "OPENAI_API_KEY environment variable is not set."
        read -p "Enter your OpenAI API key: " -s api_key
        echo
        export OPENAI_API_KEY=$api_key
        echo "export OPENAI_API_KEY=$api_key" >> ~/.bashrc
        print_status "OpenAI API key set and saved to ~/.bashrc"
    else
        print_status "OpenAI API key found in environment."
    fi
}

# Display helpful information
display_info() {
    print_status "Deployment completed successfully!"
    echo
    print_status "Cluster Information:"
    echo "Cluster Name: $(terraform output -raw cluster_name)"
    echo "Region: $(terraform output -raw region)"
    echo "Endpoint: $(terraform output -raw cluster_endpoint)"
    echo
    print_status "Demo Applications:"
    echo "The demo applications are deployed in the 'demo' namespace."
    echo "To access them via the load balancer, get the ALB DNS name:"
    echo "kubectl get ingress -n demo"
    echo
    print_status "kubectl-ai Usage:"
    echo "You can now use kubectl-ai to interact with your cluster:"
    echo "kubectl ai \"create a deployment with nginx\""
    echo "kubectl ai \"list all pods in all namespaces\""
    echo "kubectl ai \"scale the nginx-demo deployment to 5 replicas\""
    echo
    print_status "Useful Commands:"
    echo "kubectl get nodes                    # List cluster nodes"
    echo "kubectl get pods -n demo            # List demo application pods"
    echo "kubectl get pods -n kubectl-ai      # List kubectl-ai pods"
    echo "kubectl get ingress -n demo         # Get demo apps ingress info"
    echo "kubectl logs -n kubectl-ai <pod>    # Check kubectl-ai logs"
}

# Main execution
main() {
    print_status "Starting EKS cluster deployment with demo apps and kubectl-ai..."
    echo
    
    check_dependencies
    configure_aws
    deploy_infrastructure
    configure_kubectl
    install_kubectl_ai_locally
    setup_kubectl_ai
    display_info
    
    print_status "Setup complete! Your EKS cluster is ready to use."
}

# Run main function
main "$@"