# TylerCodeverse VPS — Deployment

## 1. Upload to GitHub

Use the repository:

```text
https://github.com/TylerCodeverse/tylercodeverse-vps.git
```

From this folder:

```bash
git init
git branch -M main
git remote remove origin 2>/dev/null || true
git remote add origin https://github.com/TylerCodeverse/tylercodeverse-vps.git
git add .
git commit -m "feat: TylerCodeverse VPS"
git push -u origin main
```

## 2. Deploy on Railway

Create a Railway project and choose the GitHub repository.

Railway should detect the included `Dockerfile` automatically.

## 3. Environment variables

**None are required.**

Do not create `WEB_USERNAME`, `WEB_PASSWORD` or `SSH_PASSWORD` variables for this version.

Railway's own `PORT` variable is used automatically by the application.

## 4. Generate the public link

After deployment:

1. Open the service's networking/domain settings.
2. Generate a public domain.
3. Open the generated HTTPS URL.

The browser terminal should open directly without a login form.

## 5. Add persistence

Create/attach a Railway Volume and mount it at:

```text
/data
```

## 6. SSH

The container SSH server listens on `2222`.

If TCP Proxy is available for the Railway service, map the public TCP endpoint to container port `2222`.

Use:

```text
Host: Railway TCP Proxy host
Port: Railway TCP Proxy port
Username: TylerDurdenDev
Password: TylerDurdenDev
```

The public SSH host/port are created by Railway.

## 7. Test the terminal

```bash
whoami
pwd
cd /data
echo "TylerCodeverse VPS" > test.txt
cat test.txt
```

## 8. Important

The browser URL acts as the access key in this no-login configuration. Keep the URL private if the environment contains anything sensitive.
