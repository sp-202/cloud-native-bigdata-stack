# 🐳 Custom Hive Docker Image

This image provides Hive Metastore and HiveServer2 for legacy compatibility with the platform.

## 🛠 Features
- **Hive 3.1.3**: Compatible with Spark's Hive 2.3 client
- **Hadoop 3.4.1**: Required for core JARs and bin/hadoop
- **PostgreSQL JDBC**: For connecting to PostgreSQL metadata store
- **AWS S3 Support**: Hadoop AWS with AWS SDK v2 for MinIO connectivity
- **ARM64 Native**: Built on Eclipse Temurin JDK 17 for ARM64 compatibility

## 🚀 Build Instructions
Run the provided build script to build for `linux/arm64` and push to DockerHub:
```bash
./build.sh
```

## ⚙️ Configuration
The image is designed to be **decoupled**. It does not bake in credentials. Instead, it expects:
- `hive-site.xml`: Mounted at `/opt/hive/conf/hive-site.xml` for metastore configuration
- Environment Variables: Database connection details passed at runtime

## 🛠️ How to Customize
Need extra connectors or JAR files?
1. Open the `Dockerfile` in this directory.
2. Add your custom jar download command in the appropriate section.
3. Run `./build.sh` to build and tag the new image.