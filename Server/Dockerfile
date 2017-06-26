FROM microsoft/windowsservercore:latest
SHELL ["powershell", "-Command"]
ENV OctopusAdminUsername admin
ENV OctopusAdminPassword Passw0rd123

HEALTHCHECK --interval=20s --timeout=20s --retries=6 CMD powershell -file ./Server/healthcheck-server.ps1

EXPOSE 81
EXPOSE 10943

VOLUME ["C:/Octopus", "C:/Import", "C:/Repository", "C:/Artifacts", "C:/TaskLogs"]

ADD Scripts/*.ps1 /
ADD Server/Scripts/*.ps1 /Server/

ARG OctopusVersion="latest"

LABEL 	org.label-schema.schema-version="1.0" \
		org.label-schema.name="Octopus Deploy Server" \
		org.label-schema.vendor="Octopus Deploy" \
		org.label-schema.url="https://octopus.com" \
		org.label-schema.vcs-url="https://github.com/OctopusDeploy/Octopus-Docker" \
		org.label-schema.license="Apache"  \
		org.label-schema.description="Octopus Deploy Server Instance" \
		org.label-schema.build-date=$BUILD_DATE

RUN        ./install-base.ps1 -Msi Octopus -Verbose; \
           ./Server/install-server.ps1 -Verbose
ENTRYPOINT ./Server/configure-server.ps1 -Verbose; \
           ./Server/run-server.ps1 -Verbose
