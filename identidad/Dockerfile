FROM postgres:16

COPY init/roles.sh /docker-entrypoint-initdb.d/00_roles.sh
COPY identidad/00_roles.sql /roles/00_roles.sql

RUN chmod 755 /docker-entrypoint-initdb.d/00_roles.sh
