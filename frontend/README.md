# MedCore HMS - web screens (Next.js + Tailwind CSS)

## Before you start
1. Install Node.js LTS from https://nodejs.org (version 22 or newer).
   Check it in a terminal with: `node -v`
2. Start the MedCore backend in IntelliJ. It must run on port 8080.

## Run the screens
1. Open a terminal in this folder (the one with package.json).
2. Run `npm install`. Do this once; it downloads the libraries into node_modules.
3. Run `npm run dev`.
4. Open http://localhost:3000 in Chrome.

Log in with a RECEPTIONIST or HOSPITAL_ADMIN account. The platform super admin cannot see patients.

## Where things are
- `src/app/login/page.js` - the login screen
- `src/app/patients/page.js` - the patients list, search and add form
- `src/app/appointments/page.js` - the day's appointments, the status dropdown, and the booking form
  (receptionists and hospital admins can book; doctors can view and change status)
- `src/app/portal/page.js` - the patient portal: the patient's own appointments, prescriptions and bills
- `src/components/AppFrame.jsx` - checks that someone is logged in and shows the top bar
- `src/lib/api.js` - sends requests to the backend and reads the error messages, and holds the role rules (which role starts on which screen)
- `src/lib/ui.js` - the shared Tailwind class names (colours, inputs, buttons)
- `next.config.mjs` - forwards every `/api` request to Spring Boot on port 8080

## How it works
- The browser only talks to the Next.js address (port 3000). Next.js forwards `/api` calls to the backend, so no CORS setting is needed.
- The login token is kept in sessionStorage. It is removed when the tab is closed or when you log out.
- Logging out reloads the page, so no patient data stays on screen for the next person.
