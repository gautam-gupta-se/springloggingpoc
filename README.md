# Spring Logging POC — Local Setup (Docker, Splunk, Kubernetes / KIND)

This README explains how to run the spring-logging POC locally and forward application logs to a local Splunk instance. It covers two local Kubernetes options (Colima's Kubernetes or KIND), how to build the Spring app image, deploy the app with a Splunk Universal Forwarder sidecar, and how to run Splunk Enterprise locally in Docker. It also includes verification steps.

## Checklist
- [ ] Install prerequisites (Docker / Colima, kubectl, kind (optional), Java/Gradle)
- [ ] Start Colima (if using Colima) with Rosetta / correct arch
- [ ] Run Splunk Enterprise (Docker) or deploy Splunk inside the cluster
- [ ] Build Spring Boot jar and Docker image
- [ ] Deploy `app-sidecar-deployment.yaml` (or adjust for KIND)
- [ ] Port-forward the Spring app and exercise endpoints to generate logs
- [ ] Verify events arrive in Splunk

## Prerequisites
- macOS (with Rosetta if using x86_64 images on Apple Silicon)
- Docker (or Colima configured as Docker runtime)
- kubectl
- (optional) kind (if you prefer KIND over Colima's Kubernetes)
- Java 17+ and Gradle (to build the jar), or use the provided `build/libs` jar

## VM / Docker setup (Colima with Rosetta)
If you're on Apple Silicon and need to run x86_64 images, the user-provided Colima command is a good starting point.

Run this to start Colima (example provided by you):

```bash
colima start --cpu 4 --memory 6 --vm-type vz --vz-rosetta --kubernetes --arch x86_64
```

Notes:
- This starts a Colima VM configured for x86_64 images and enables Kubernetes in Colima. If you want to use KIND instead, see the KIND section below.

## Run Splunk Enterprise locally (Docker)
The container below runs Splunk Enterprise with web UI on 8000 and the Splunk receiving port 9997.

```bash
docker run -d \
  --platform linux/amd64 \
  --name splunk-enterprise \
  -p 8000:8000 \
  -p 9997:9997 \
  -e SPLUNK_GENERAL_TERMS=--accept-sgt-current-at-splunk-com \
  -e SPLUNK_START_ARGS=--accept-license \
  -e SPLUNK_PASSWORD=Password123! \
  splunk/splunk:9.3

docker logs -f splunk-enterprise
```

Access Splunk web UI: http://localhost:8000
- Username: admin
- Password: Password123!

Important Splunk UI steps (one-time after container has started):
- Go to Settings -> Forwarding and receiving -> Receive -> New
- Create a receiver on port 9997 (this enables the indexer to accept UF connections)
- (Optional) Create an index (e.g., `main` or `spring-logs`) or use `main` already referenced in the sidecar manifest

## Options for making Splunk reachable from Kubernetes pods
1) Run Splunk inside the same Kubernetes cluster (recommended for simplicity)
   - Deploy Splunk as a Deployment/Service in your cluster and set the sidecar `SPLUNK_STANDALONE_URL` to `splunk-enterprise:9997` (the service name)
2) Run Splunk as Docker on the host (you did above)
   - When using Colima's Kubernetes or Docker-in-Colima, pods usually can reach `host.docker.internal:9997` or the container IP. Use `host.docker.internal:9997` in `SPLUNK_STANDALONE_URL` for the sidecar.
3) Use the host IP (e.g., `192.168.x.y:9997`) — replace the placeholder in `app-sidecar-deployment.yaml`

Note about the provided `app-sidecar-deployment.yaml`
- The manifest already contains two containers: the Spring app and a `splunk/universalforwarder:9.3` sidecar.
- The sidecar uses the env var `SPLUNK_STANDALONE_URL` (line currently contains `192.168.1.34:9997`) — replace it with whichever address is reachable from the pod:
  - `splunk-enterprise:9997` (if Splunk runs inside the cluster)
  - `host.docker.internal:9997` (if Splunk runs in Docker on the host and your runtime supports host.docker.internal)
  - `<your-host-ip>:9997` (if you prefer to use host IP)

## Build & deploy the Spring Boot app image
From the project root (where `gradlew` and `Dockerfile` are), run:

```bash
./gradlew clean bootJar

# Build the Docker image (this uses the jar produced at build/libs/*-SNAPSHOT.jar)
docker build -t local/spring-gradle-app:1.0 .
```

If you're using KIND
- Create a kind cluster (example):

```bash
# install kind if necessary
# brew install kind
kind create cluster --name spring-poc
```

- Load the image into the kind cluster so pods can use it:

```bash
kind load docker-image local/spring-gradle-app:1.0 --name spring-poc
```

If you're using Colima's Kubernetes
- Colima's Docker socket is typically the same Docker used to build images, so you can just `docker build` and the image will be available to the cluster. If you set imagePullPolicy: Never in the manifest it will use the local image.

## Deploy the app-sidecar manifest

```bash
# (optionally edit app-sidecar-deployment.yaml first to set SPLUNK_STANDALONE_URL correctly)
kubectl apply -f app-sidecar-deployment.yaml
```

Verify pods are running:

```bash
kubectl get pods -l app=spring-app -o wide
kubectl describe pod -l app=spring-app
```

## Port-forward the Spring app to your Mac's localhost

```bash
kubectl port-forward deployment/spring-app-logging-poc 8080:8080
# Now the app is reachable at http://localhost:8080/ and http://localhost:8080/helloMessage
```

## Generate logs (exercise endpoints)

```bash
curl http://localhost:8080/
curl http://localhost:8080/helloMessage
# Repeat a few times to generate more log events
```

## Check the universal forwarder and forwarder status

```bash
# Get logs from the Splunk sidecar container
kubectl logs deployment/spring-app-logging-poc -c splunk-sidecar --follow

# Get logs from the spring app container
kubectl logs deployment/spring-app-logging-poc -c spring-app --follow
```

## Verify events in Splunk
- Open Splunk Web (http://localhost:8000)
- Search for recent events. Example search (adjust index/sourcetype as appropriate):

```
index=main "this is default controller"
```

- If you used a different index, change the index name in the search.

## Troubleshooting
- If you don't see events in Splunk:
  - Ensure the Splunk container is running and that you created a receiver on port 9997.
  - Check that the `SPLUNK_STANDALONE_URL` value in `app-sidecar-deployment.yaml` is reachable from within the pod. Test connectivity from a debug pod in the same namespace (e.g., `kubectl run -it --rm debug --image=alpine -- sh` and use `nc -vz <host> 9997` if nc is available or `wget --spider`).
  - Check the sidecar logs (`kubectl logs ... -c splunk-sidecar`) for connection errors.
  - If using KIND and running Splunk on your host, ensure `host.docker.internal` is resolvable from the cluster. For kind, host.docker.internal is supported if Docker on the host supports it; otherwise prefer running Splunk inside the cluster.

### Why we modified the deployment (race condition & ownership issues)

During testing we observed the Splunk Universal Forwarder (UF) sometimes did not monitor the application log path because of a race and a ConfigMap ownership issue:

- Race condition: if the UF starts before the Spring container has created the `/var/log/app/spring-app.log` file, a file-specific monitor may be missed. Monitoring the directory is more robust, but the configuration must be present before UF provisioning finishes.
- Ownership/ConfigMap issue: mounting a ConfigMap over `/opt/splunkforwarder/etc/system/local` can replace the directory with a read-only mount. The UF's Ansible provisioning tries to chown/chgrp that directory and fails (you saw `chgrp failed` and Ansible retrying), which delays or breaks startup.

Changes made in this repo to mitigate these problems:

- We changed `inputs.conf` to monitor the directory (`[monitor:///var/log/app/]`) so rotated/new files are picked up instead of relying on a single file path.
- We switched from mounting the whole ConfigMap directory to mounting a single `inputs.conf` file via `subPath` (or using an init container in the optimized manifest). This prevents masking the `system/local` directory and avoids `chgrp` failures during provisioning.
- We added an option that ensures the log file exists early (a `postStart` lifecycle on the `spring-app` container that `touch`es the file) so the file path is present when UF registers monitors.
- An optimized manifest (`app-sidecar-deployment-optimized.yaml`) is provided that uses an init container to write `inputs.conf` into an `emptyDir` before the UF starts — this guarantees the UF starts with the config already present and avoids ConfigMap-related ownership issues.

 Verified the forwarder manually after these changes using the CLI:

```bash
kubectl exec -it deployment/spring-app-logging-poc -c splunk-sidecar -- /opt/splunkforwarder/bin/splunk list monitor -auth admin:SidecarPassword123
```

That command showed `/var/log/app/spring-app.log` in the monitored files, confirming the UF can read and forward the file.

Alternate options (summary)

- Monitor the directory instead of a single file (preferred): reduces issues with rotated files or late file creation. We implemented this in `inputs.conf`.
- Init container to write `inputs.conf` (recommended): guarantees configuration exists before UF provisioning starts (`app-sidecar-deployment-optimized.yaml`).
- `postStart` lifecycle on the app container (minimal change): ensure the log path/file exists early by creating/touching it (this prevents file-not-found monitors).
- Mount `inputs.conf` as a single file with `subPath` instead of mounting the whole ConfigMap directory (prevents read-only masking and chgrp failures).
- Automate `splunk add monitor` at runtime (scripted): run the CLI to add monitor after UF is up — works but is less declarative than ConfigMap/init container approaches.
- Use Splunk Connect for Kubernetes (SC4K) or Fluent Bit/Fluentd: production-grade alternatives that avoid per-pod UF sidecars and integrate better with k8s metadata and HEC.

If you want, I can add the `postStart` snippet directly into `app-sidecar-deployment.yaml` in the repo so deployments created from this manifest always ensure the file exists. Alternatively I can update the README to show the exact `kubectl patch` command to add the lifecycle to an existing deployment.

## Extra: Deploy Splunk Enterprise in Kubernetes (example sketch)
- You can avoid host networking issues by deploying Splunk as a Deployment + Service inside the same cluster. Then change the sidecar `SPLUNK_STANDALONE_URL` to `splunk-enterprise:9997` (service name). A production-ready Splunk on k8s deployment is more complex — this is only for local testing.

## Cleaning up

```bash
kubectl delete -f app-sidecar-deployment.yaml
# if you created a kind cluster
kind delete cluster --name spring-poc
# stop and remove splunk container
docker stop splunk-enterprise && docker rm splunk-enterprise
colima stop
```

## Notes and recommended next steps
- For more robust Kubernetes logging in real clusters consider Fluentd/Fluent Bit or Splunk Connect for Kubernetes (SC4K) which collects stdout, cluster metadata, and K8s logs and forwards to Splunk's HTTP Event Collector (HEC). SC4K integrates better with k8s and does not require sidecars.
- The provided sidecar approach is useful for simple POCs where bundling the Universal Forwarder with the app is desired.

If you want, I can:
- Add a Kubernetes Service and an updated `app-sidecar-deployment.yaml` with an easier-to-edit `SPLUNK_STANDALONE_URL` configMap
- Create a small `splunk-deployment.yaml` to run Splunk inside the cluster for easier connectivity

---
File references in this repo used by these instructions:
- `Dockerfile` — builds the app image from `build/libs` jar
- `app-sidecar-deployment.yaml` — deployment that mounts a shared volume and runs a Splunk UF sidecar
- `src/main/java/com/example/springlogingpoc/DemoController.java` — app endpoints used to generate logs

Happy to update the repo with automation (kustomize/helm) or a simple script that replaces the SPLUNK_STANDALONE_URL placeholder with the right value for your environment.

