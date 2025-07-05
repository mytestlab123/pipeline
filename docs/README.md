# Nextflow Offline Execution Demo

Complete guide for running nf-core pipelines on AWS EC2 instances without internet access.

## Overview

This project enables running Nextflow pipelines in offline environments through a two-phase workflow:

1. **Online Phase**: Download pipeline assets and Docker images on internet-connected machine
2. **Offline Phase**: Load assets and execute pipeline on isolated/air-gapped machine

## Quick Start

```bash
# Complete end-to-end demo
./demo.sh

# Validate environment only
./demo.sh validate

# Run online phase only
./demo.sh online-only
```

## Prerequisites

### Required Tools
- **Git**: For downloading pipeline assets
- **Docker**: Container runtime (4.0+ recommended)
- **Nextflow**: Workflow management system (22.10.0+ recommended)
- **curl**: For connectivity testing

### AWS Environment
- **EC2 Instance**: t3.medium or larger (2+ vCPU, 4+ GB RAM)
- **Storage**: 10+ GB available disk space
- **Network**: Internet access for online phase

### Authentication
- **Docker Hub**: Account with push/pull permissions
- **GitHub**: Access to nf-core repositories (public)

## Installation

### AWS EC2 Setup (Amazon Linux 2)

```bash
# Update system
sudo yum update -y

# Install Docker
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

# Install Git
sudo yum install -y git

# Install Nextflow
curl -s https://get.nextflow.io | bash
sudo mv nextflow /usr/local/bin/
chmod +x /usr/local/bin/nextflow

# Verify installation
docker --version
git --version
nextflow -version
```

### Project Setup

```bash
# Clone repository
git clone https://github.com/mytestlab123/pipeline.git
cd pipeline

# Validate environment
./demo.sh validate
```

## Configuration

### Docker Hub Authentication (Optional)

Create `.env` file for Docker Hub access:

```bash
# .env file
DOCKER_USER=your_docker_username
DOCKER_PAT=your_personal_access_token
```

> **Note**: Without Docker Hub credentials, the demo will use publicly available images

### AWS IAM Permissions

For S3 asset storage (future enhancement):

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::your-bucket-name",
                "arn:aws:s3:::your-bucket-name/*"
            ]
        }
    ]
}
```

## Usage

### Complete Workflow

```bash
# Run complete online → offline workflow
./demo.sh

# View performance report
cat /tmp/demo-performance-report.txt

# View detailed logs
cat /tmp/demo-execution.log
```

### Phase-by-Phase Execution

```bash
# Online phase only (internet-connected machine)
./demo.sh online-only

# Transfer assets to offline machine
# rsync -av ./offline-assets/ offline-machine:/path/to/assets/

# Offline phase only (air-gapped machine)
./demo.sh offline-only
```

### Individual Script Usage

```bash
# 1. Download pipeline assets
./online-prepare.sh

# 2. Generate Docker image list
./generate-image-list.sh

# 3. Pull and copy Docker images
./pull-images.sh

# 4. Setup offline environment
./offline-setup.sh

# 5. Run offline pipeline
./run-offline-pipeline.sh
```

## Asset Structure

```
offline-assets/
├── pipeline/              # nf-core/demo pipeline files
│   ├── main.nf           # Main workflow
│   ├── nextflow.config   # Pipeline configuration
│   └── modules/          # Process modules
├── images.txt            # Docker image list
├── images-manifest.txt   # Image metadata
├── manifest.txt          # Asset inventory
└── *.log                 # Execution logs
```

## Performance Benchmarks

Typical execution times on t3.medium instance:

- **Online Phase**: 30-60 seconds
- **Offline Phase**: 45-90 seconds
- **Total Demo**: 2-3 minutes

Resource requirements:
- **CPU**: 2+ vCPU recommended
- **Memory**: 4+ GB RAM
- **Storage**: 5+ GB for assets + images
- **Network**: 10+ Mbps for online phase

## Troubleshooting

### Common Issues

#### "Docker daemon not running"
```bash
sudo systemctl start docker
sudo systemctl enable docker
```

#### "Permission denied" for Docker
```bash
sudo usermod -a -G docker $(whoami)
# Log out and log back in
```

#### "No internet connectivity"
```bash
# Check network connectivity
curl -I https://github.com
ping -c 3 github.com

# Verify DNS resolution
nslookup github.com
```

#### "Failed to pull Docker images"
```bash
# Check Docker Hub credentials
docker login

# Verify .env file format
cat .env
# Should contain: DOCKER_USER=username and DOCKER_PAT=token
```

#### "Nextflow command not found"
```bash
# Install Nextflow
curl -s https://get.nextflow.io | bash
sudo mv nextflow /usr/local/bin/
```

### Log Analysis

```bash
# View demo execution log
cat /tmp/demo-execution.log

# Check individual script logs
ls -la /tmp/*-*.log

# View pipeline execution logs
ls -la ./work/
```

### Validation Commands

```bash
# Validate environment
./demo.sh validate

# Test individual components
./test/run-all-tests.sh

# Check asset integrity
find ./offline-assets -type f | wc -l
```

## Advanced Configuration

### Custom Pipeline Support

To adapt for other nf-core pipelines:

1. Modify `PIPELINE_NAME` and `PIPELINE_VERSION` in scripts
2. Update image extraction logic in `generate-image-list.sh`
3. Adjust configuration in `offline-setup.sh`

### S3 Asset Storage

For S3-based asset storage (future enhancement):

```bash
# Upload assets to S3
aws s3 sync ./offline-assets/ s3://your-bucket/offline-assets/

# Download on offline machine
aws s3 sync s3://your-bucket/offline-assets/ ./offline-assets/
```

### Performance Optimization

```bash
# Use faster instance types
# t3.large or larger for faster execution

# Optimize Docker images
# Use multi-stage builds and smaller base images

# Parallel processing
# Increase Nextflow executor settings
```

## Security Considerations

- **Credentials**: Never commit `.env` files to version control
- **Network**: Use VPC endpoints for S3 access in offline environments
- **Images**: Scan Docker images for vulnerabilities before deployment
- **Assets**: Validate checksums of downloaded assets

## Architecture

### Two-Phase Workflow
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Online Phase  │    │  Asset Storage  │    │  Offline Phase  │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │Download     │ │───▶│ │Docker Hub   │ │───▶│ │Load Assets  │ │
│ │Pipeline     │ │    │ │or S3 Bucket │ │    │ │& Run        │ │
│ │Assets       │ │    │ │             │ │    │ │Pipeline     │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │Generate     │ │    │ │Pipeline     │ │    │ │Execute      │ │
│ │Image List   │ │    │ │Code (GitHub)│ │    │ │with -offline│ │
│ └─────────────┘ │    │ └─────────────┘ │    │ │flag         │ │
│                 │    │                 │    │ └─────────────┘ │
│ ┌─────────────┐ │    │                 │    │                 │
│ │Pull & Save  │ │    │                 │    │                 │
│ │Docker Images│ │    │                 │    │                 │
│ └─────────────┘ │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
     Internet              Shared Storage         Private Subnet
    Connection                                   (No Internet)
```

## Support

- **GitHub Issues**: [Report bugs and request features](https://github.com/mytestlab123/pipeline/issues)
- **Documentation**: Additional docs in `docs/` directory
- **Logs**: All logs stored in `/tmp/` directory for analysis

## License

This project is licensed under the MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/new-feature`
3. Commit changes: `git commit -am 'Add new feature'`
4. Push to branch: `git push origin feature/new-feature`
5. Create Pull Request

## Acknowledgments

- **nf-core**: For providing standardized Nextflow pipelines
- **Nextflow**: For the workflow management system
- **Docker**: For containerization technology
- **AWS**: For cloud infrastructure platform