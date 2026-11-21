import { redirect } from "next/navigation";

export default function LegacyAgePage() {
  redirect("/users/closed-by-age");
}
