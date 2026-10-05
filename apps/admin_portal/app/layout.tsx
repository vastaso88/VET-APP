import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "VET APP Admin",
  description: "Internal operations portal for VET APP",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
