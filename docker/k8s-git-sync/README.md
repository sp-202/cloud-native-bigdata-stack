# 🐳 Custom k8s-git-sync Docker Image

This image provides a Git synchronization sidecar with MinIO client integration for Airflow DAG deployment.

## 🛠 Features
- **git-sync v4.2.3**: Official Kubernetes git-sync binary for Git repository synchronization
- **MinIO Client (mc)**: For mirroring Git repository contents to MinIO object storage
- **Custom Sync Hook**: Automated mirroring of Git repository to MinIO bucket
- **Multi-architecture**: Supports both amd64 and arm64 platforms

## 🚀 Build Instructions
Run the provided build script to build for your target architecture and push to DockerHub:
```bash
./build.sh
```

## ⚙️ Configuration
The image uses environment variables for configuration:
- `MINIO_ACCESS_KEY`: Access key for MinIO authentication
- `MINIO_SECRET_KEY`: Secret key for MinIO authentication

The sync hook script automatically configures the MinIO alias and mirrors the repository contents to the `dags` bucket.

## 🛠️ How to Customize
Need additional tools or functionality?
1. Open the `Dockerfile` in this directory.
2. Add your required packages to the `apt-get install` command or add additional installation steps.
3. Modify the `sync-hook.sh` script if you need different synchronization logic.
4. Run `./build.sh` to build and tag the new image.