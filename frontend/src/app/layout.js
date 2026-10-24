import "./globals.css";

export const metadata = {
  title: "MedCore HMS",
  description: "Hospital management screens for MedCore HMS",
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body className="min-h-screen antialiased">{children}</body>
    </html>
  );
}
