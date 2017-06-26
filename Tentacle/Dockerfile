FROM microsoft/windowsservercore:latest
SHELL ["powershell", "-Command"]

HEALTHCHECK --interval=20s --timeout=20s --retries=6 CMD powershell -file ./Tentacle/healthcheck-tentacle.ps1

EXPOSE 10933

VOLUME ["C:/Applications", "C:/TentacleHome"]

ADD Scripts/*.ps1 /
ADD Tentacle/Scripts/*.ps1 /Tentacle/
ADD Installers/ /Installers

ARG OctopusVersion="latest"

LABEL 	org.label-schema.schema-version="1.0" \
		org.label-schema.name="Octopus Deploy Tentacle" \
		org.label-schema.vendor="Octopus Deploy" \
		org.label-schema.url="https://octopus.com" \
		org.label-schema.vcs-url="https://github.com/OctopusDeploy/Octopus-Docker" \
		org.label-schema.license="Apache"  \
		org.label-schema.description="Octopus Tentacle instance with auto-registration to Octopus Server" \
		org.label-schema.build-date=$BUILD_DATE

RUN        ./install-base.ps1 -Msi Octopus.Tentacle -Verbose; \
           ./Tentacle/install-tentacle.ps1 -Verbose
ENTRYPOINT ./Tentacle/configure-tentacle.ps1 -Verbose; \
           ./Tentacle/run-tentacle.ps1 -Verbose
