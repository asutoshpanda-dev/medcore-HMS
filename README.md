# MedCore HMS

A hospital management system built as an internship project.

- **Backend** (`backend/`): Java 25, Spring Boot 4, Spring Security with JWT, MySQL 8, Flyway migrations
- **Frontend** (`frontend/`): Next.js 16 (App Router), React 19, Tailwind CSS 4

## What is built
- Five roles: platform super admin, hospital admin, doctor, receptionist, patient.
- Staff screens: patient list with search and add form, day view of appointments with status changes, and booking (double bookings are refused).
- Patient portal: the patient's own appointments, prescriptions and bills.
- REST API with Swagger UI at `/swagger-ui.html`.

Medical records and billing exist in the API but have no screens yet.

## Repository layout
```
backend/      Spring Boot API, SQL migrations, tests, Dockerfile
frontend/     Next.js web screens
.github/      CI: builds and tests the backend, builds the frontend
DEPLOY.md     How the public demo is hosted, step by step
```

## Run on your computer
**Backend**
1. Create an empty MySQL 8 database named `medcore_hms`.
2. Set the environment variables listed in `DEPLOY.md` (section 3) in your IntelliJ run configuration. Do not create a copy of `application.properties` with real values inside the repo; the file is git-ignored, but keeping secrets in environment variables is safer.
3. Run `MedcoreHmsApplication`. It listens on port 8080.

**Frontend**
1. Install Node.js 22 or newer.
2. In the `frontend` folder, run `npm install`, then `npm run dev`.
3. Open http://localhost:3000.

**Tests**
- Backend: `cd backend` then `./mvnw verify` (Windows: `mvnw.cmd verify`). The tests use an in-memory H2 database.
- The PowerShell scripts in `backend/scripts` call a running backend on localhost:8080. They read the admin password from the `ADMIN_PASSWORD` environment variable.

## Security
- Passwords are stored as BCrypt hashes, never in plain text.
- Login returns a JWT signed with HMAC-SHA256. The secret comes from an environment variable.
- The browser only calls the Next.js address. Next.js forwards `/api` requests to the backend.
- No passwords, keys or database details are stored in this repository.

## Live demo
- Web app: https://medcore-hms-ten.vercel.app
- API documentation: https://medcore-hms-ngcq.onrender.com/swagger-ui.html

The free hosting goes to sleep when idle. The first visit can take about a minute. See `DEPLOY.md`.
