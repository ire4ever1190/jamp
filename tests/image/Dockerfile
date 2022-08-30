FROM docker.io/linagora/tmail-backend:memory-0.5.0
# Copy keys across to save us having to bind them
COPY jwt_privatekey /root/conf/jwt_privatekey
COPY jwt_publickey /root/conf/jwt_publickey
COPY jmap.properties /root/conf/jmap.properties
COPY provision.sh /root/provision.sh
COPY eml/ /root/eml/
EXPOSE 80
EXPOSE 8080
EXPOSE 443
EXPOSE 8443
