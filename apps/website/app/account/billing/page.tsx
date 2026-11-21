import Link from "next/link";
import {api} from "../../../lib/api";
export const dynamic="force-dynamic";
export const metadata={title:"Abbonamento",robots:{index:false,follow:false}};
export default async function Billing(){
 const me=await api("/auth/me");if(!me.ok)throw new Error("Account unavailable");
 return <section className="account"><Link href="/account">Area personale</Link><h1>Il tuo abbonamento.</h1><p>Gli abbonamenti saranno disponibili direttamente in app tramite App Store e Google Play. La configurazione degli acquisti negli store avverra separatamente.</p><Link href="/account">Consulta lo stato del tuo account</Link></section>;
}
