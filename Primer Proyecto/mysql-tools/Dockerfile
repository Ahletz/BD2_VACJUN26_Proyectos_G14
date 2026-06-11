FROM oraclelinux:9-slim

RUN microdnf install -y curl ca-certificates \
    && curl -fsSL \
       https://repo.mysql.com/RPM-GPG-KEY-mysql-2025 \
       -o /tmp/RPM-GPG-KEY-mysql-2025 \
    && rpm --import /tmp/RPM-GPG-KEY-mysql-2025 \
    && curl -fsSL \
       https://dev.mysql.com/get/mysql84-community-release-el9-4.noarch.rpm \
       -o /tmp/mysql-release.rpm \
    && rpm -Uvh /tmp/mysql-release.rpm \
    && microdnf install -y mysql-community-client \
    && microdnf clean all \
    && rm -f /tmp/mysql-release.rpm \
       /tmp/RPM-GPG-KEY-mysql-2025

CMD ["tail", "-f", "/dev/null"]
