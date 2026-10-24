# Deploying MedCore HMS on free hosting

The app has three parts, and each one runs on its own free service:

| Part | Service | Why this one |
|---|---|---|
| MySQL database | Aiven (free MySQL plan) | Render's free database is PostgreSQL only, and the app uses MySQL |
| Backend (Spring Boot, in Docker) | Render (free web service) | Runs the Dockerfile in `backend/` |
| Frontend (Next.js) | Vercel (Hobby plan) | Built for Next.js; forwards `/api` to the backend |

Free plans change. Check each service's current limits before the review.

---

## 1. Database on Aiven
1. Sign up at aiven.io and create a **MySQL** service on the free plan. Pick a region close to you. The free plan does not guarantee which region you get.
2. When the service is running, copy the **host**, **port**, **user** and **password** from its overview page.
3. Create the database. In MySQL Workbench (or any MySQL client connected to Aiven) run:
   ```sql
   CREATE DATABASE medcore_hms;
   ```
4. The backend connects over SSL. The connection string has this shape:
   ```
   jdbc:mysql://HOST:PORT/medcore_hms?sslMode=REQUIRED
   ```
   Use the host and port from Aiven's connection information. Flyway creates all the tables on the first start, so the database can be empty.

## 2. Create a JWT secret
Run this in PowerShell. It prints a random 64-character secret:
```powershell
$b = New-Object byte[] 48; (New-Object System.Security.Cryptography.RNGCryptoServiceProvider).GetBytes($b); [Convert]::ToBase64String($b)
```
Paste the result only into Render's environment variables. Never put it in Git or in a chat.

## 3. Backend on Render
1. Sign in at render.com and choose **New → Web Service**. Connect your GitHub repository.
2. Set **Root Directory** to `backend`, **Runtime** to **Docker**, and **Instance Type** to **Free**.
3. Add these environment variables:

| Name | Value |
|---|---|
| `DB_URL` | `jdbc:mysql://HOST:PORT/medcore_hms?sslMode=REQUIRED` (from step 1) |
| `DB_USERNAME` | the Aiven user name |
| `DB_PASSWORD` | the Aiven password |
| `JWT_SECRET` | the secret from step 2 (at least 32 characters) |
| `JWT_EXPIRATION_MINUTES` | `60` |
| `SUPER_ADMIN_USERNAME` | a username you choose |
| `SUPER_ADMIN_PASSWORD` | a new password of at least 8 characters |

   Render sets `PORT` automatically; do not add it yourself.

4. Click **Deploy**. In the logs, look for the Flyway messages about applying migrations, for `Created super admin user` on the first start, and for the application starting without errors.
5. Open `https://YOUR-SERVICE.onrender.com/swagger-ui.html`. If the API page loads, the backend is up.

## 4. Frontend on Vercel
1. Sign in at vercel.com and choose **Add New → Project**. Import the same GitHub repository.
2. Set **Root Directory** to `frontend`. Vercel detects Next.js automatically.
3. Before the first deploy, add an environment variable:
   - Name: `API_URL`
   - Value: `https://YOUR-SERVICE.onrender.com` (no trailing slash, no `/api`)
4. Click **Deploy**. The value is built into the site, so if you change `API_URL` later, redeploy the project.

## 5. Create accounts for the demo
- Log in through Swagger (`POST /api/auth/login`) as the super admin.
- Create a hospital with `POST /api/hospitals`, and check the Swagger descriptions for the verify step (`PATCH /api/hospitals/{id}/verify`).
- Create a hospital admin or receptionist with `POST /api/auth/register`. The body has `username`, `password` (8 to 72 characters), `role`, `hospitalId`, and `patientId` for patient accounts.
- Use new passwords. Do not write them in this repository.

The super admin cannot see patients. Use a hospital admin or receptionist to test the staff screens, and a patient account to test the portal.

## 6. Limits of the free plans
- **Render sleeps** after about 15 minutes without traffic. The first request after that can take about a minute. Open the Swagger page a few minutes before a review.
- **Aiven can pause** an idle free service. If the site shows errors, check the service status in Aiven and start it.
- **Password reset codes** are printed to the Render logs (`app.otp.mode=log`). This is for demos only. Do not enter real personal data.
- After the review, change the super admin password and the JWT secret, or delete the services.

## Troubleshooting
| Symptom | Likely cause |
|---|---|
| Startup error mentioning a placeholder such as `DB_PASSWORD` | That environment variable is missing or misspelled in Render |
| Database connection or SSL error | Check the host, port and `sslMode=REQUIRED` in `DB_URL` |
| Hibernate schema validation error at startup | The database does not match the code. Check the Flyway messages in the logs |
| Login on the Vercel site fails or times out | Render is waking up, or `API_URL` is wrong. Wait a minute, check it, then redeploy if needed |
