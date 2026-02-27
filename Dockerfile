FROM registry.cn-shenzhen.aliyuncs.com/sailfish/runnode-llamacpp-glm47-opencode:v20260222-llamacpp-opencode-openclaw-r1-llamacpp-opencode-1.2.10-manager-main

# Mission Control: use abhi1693 fork (master branch)
ARG OPENCLAW_MISSION_CONTROL_REF=main

WORKDIR /workspace

# Mission Control already exists in base image at /opt/openclaw-mission-control
# Just ensure correct permissions
RUN chmod -R 755 /opt/openclaw-mission-control 2>/dev/null || true

COPY --chmod=755 start.sh /start.sh

ENTRYPOINT ["/start.sh"]
