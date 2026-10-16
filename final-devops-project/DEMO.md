# SpendWise: 5-minute live demo script

**Author:** Abhinav (24BCS10282) · used for the final presentation (rubric M10). Every step was rehearsed and recorded; see the [README](README.md#live-demo-m10-commit--pipeline--deployment-update-recorded).

## Before the session (5 minutes, laptop plugged in, lid open)

```bash
cd final-devops-project
minikube start                     # the cluster keeps all state between restarts
make mode-gitops                   # 8 GB laptop: Argo CD on, monitoring stack paused
make status                        # Argo CD Synced/Healthy, Pods Running
make port-forward                  # leave this terminal open
caffeinate -dims &                 # stop the Mac from sleeping during the demo
```

Open these tabs:

1. http://spendwise.local:18080 (needs `127.0.0.1 spendwise.local` in `/etc/hosts`)
2. Argo CD: http://localhost:8081/applications/argocd/spendwise
3. GitHub Actions: https://github.com/Abhinavsuri90/DevOps-Coursework-final/actions
4. This repository's `final-devops-project/README.md`

## The demo

| Time | Show | Say |
| --- | --- | --- |
| 0:00 | The app (tab 1). Add an expense | "SpendWise is my own app: React UI, FastAPI API, PostgreSQL. The footer shows the exact commit that is running." |
| 0:40 | README → Architecture diagram | "A push runs tests and security scans, builds two images, pushes them to GHCR with the commit SHA, deploys to a throwaway kind cluster, and then commits the new tag to Git. Argo CD deploys from Git. CI never touches my cluster." |
| 1:20 | Edit `application/frontend/src/App.jsx` (the subtitle), then `git commit -am "Demo: new subtitle"` and `git push` | "One commit, nothing else by hand." |
| 1:40 | Actions tab → the new run → job graph | "Lint and tests, then SAST, SCA, secret and IaC scans in parallel, image builds with Trivy, the security gate, the push, the kind deploy with helm test and an Ingress smoke test, then the GitOps commit." Open a *Trivy image scan* annotation: "0 HIGH or CRITICAL; if there were any, the gate would stop the release." |
| 3:00 | While it runs: `kubectl -n spendwise scale deploy/spendwise-frontend --replicas=1`, then Argo CD (tab 2) | "Self-heal: Git says 2 replicas, so Argo CD puts it back within seconds." |
| 3:30 | Pipeline green → `git pull` shows `gitops: deploy spendwise <sha>` | "The only thing CI changed is the two image tags in `values-gitops.yaml`." |
| 4:00 | Argo CD syncs (≤ about 1 minute), then `make status` | "New Pods with the new tag, rolled out one by one with zero downtime." |
| 4:30 | Refresh the app: new subtitle, footer shows the new SHA | "The deployment updated to exactly the commit I pushed." |
| 4:45 | README → Troubleshooting | "I also broke it on purpose five times (image tag, Ingress host, Secret, metrics path, HPA requests) and fixed each one; the transcripts are in `evidence/`." |

## If something goes wrong

| Symptom | Quick fix |
| --- | --- |
| The app tab says *connection refused* | The port-forward stopped. Run `make port-forward` again |
| Argo CD hasn't synced after 2 minutes | Argo CD UI → **Refresh**, or `kubectl -n argocd annotate applications.argoproj.io spendwise argocd.argoproj.io/refresh=normal --overwrite` |
| Pods restarting after the laptop slept | `minikube stop && minikube start`, then `make status` |
| Prometheus/Grafana are needed for questions | `make mode-monitoring` (pauses Argo CD, starts Prometheus, Alertmanager, Grafana and demo traffic), then http://localhost:9090 and http://localhost:3000 (Dashboards → *SpendWise - Application Overview*). `make mode-gitops` switches back |
| The pipeline is slow | Show the recorded run in the README while it finishes |
