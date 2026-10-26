> **BOZZA — non è consulenza legale; da rivedere da un avvocato abilitato negli USA prima della pubblicazione**

**Note per il team (da eliminare prima della pubblicazione):** testo destinato agli utenti USA, in inglese americano semplice. Parti tra [parentesi quadre] da compilare o verificare; i punti "VERIFY" sono fatti da confermare nel codice/contratti. Basato su docs/compliance/09_informativa_privacy_bozza.md (informativa italiana) e sulla ricerca in 01_ricerca_normativa.md. Fonti e incertezze: vedi 01. Nessun dato personale reale: indirizzi e nomi sono segnaposto.

---

# VetApp Privacy Policy (United States)

**Effective date:** [MM/DD/YYYY] **Version:** us-v1 **Last updated:** [MM/DD/YYYY]

This policy explains what personal information VetApp collects, why, who we share it with, and what choices you have. It applies to the VetApp mobile app and website for users in the United States. We wrote it in plain English. If something is unclear, write to us at the contact address below.

## 1. Who we are

VetApp is operated by [Company legal name] ("VetApp," "we," "us"), [12 Main St, City, ST 00000, USA / registered address]. Privacy contact: [privacy@example.com]. [VERIFY: the company is established in Italy; the privacy contact and a U.S.-facing mailing address (needed for email marketing) are placeholders.]

VetApp is for pet owners. VetApp is **not a veterinarian** and does not give veterinary diagnoses or prescriptions (see our AI and Veterinary Notice).

## 2. Who can use VetApp

VetApp is for people **18 or older** [VERIFY: age of majority varies by state]. It is not directed to children, and we do not knowingly collect personal information from anyone under 13. If you think a child has given us information, contact us and we will delete it.

## 3. What we collect

| What | Examples | Where it comes from |
|---|---|---|
| Account | Email, name, sign-up date, your consent choices with date and version, language and region shown to you when you chose | You, when you sign up |
| Your pets | Pet's name, species, breed, age, weight, notes, photos and videos | You |
| Documents and health records for your pet | Documents you upload, vet visits, vaccines, lab results. These may also contain **your** information or someone else's (for example, a name, phone number, or address) | You |
| Chat | Your questions, the answers, attachments, voice messages (we turn them into text to answer) | You and our system |
| Location | GPS location, only if you allow it in your phone settings, or an address you type. For walks: GPS points with date, time, and accuracy, linked to your account and your pet | You, through your phone |
| Contributions | Place reports, dog-park star ratings, votes. Shown to others without your name | You |
| Technical | IP address, device and app version, server logs | Automatically |
| Subscription | Plan you chose, trial start and end dates. [No payment card data is collected yet / Card payments are handled by [payment provider]; we don't see your full card number.] | You and our system |

**We do not intentionally collect:** Social Security numbers, financial account numbers, or government ID numbers. Please don't upload them in documents or chat. Our system tries to remove some personal details before sending text to our AI provider, but it can't catch everything (see Section 6).

### Phone permissions

The app asks for a permission only when you use a feature that needs it. If you say no, that feature stays off and the rest of the app keeps working.

- **Location (while using the app):** set your area, find nearby places, record walks. During an active walk, location continues in the background and a notification is visible. [VERIFY: tracking stops when the walk ends.]
- **Microphone:** record a voice message for chat.
- **Notifications:** remind you about vaccines and medicines. No data is collected for this.
- **Photos, video, camera, files:** add pet photos and videos or attach documents. The app uses the system picker and only reads the files you choose. [VERIFY after Android manifest fix.]

## 4. Why we use your information

- To create and run your account and give you the service (pets, reminders, chat, walks, nearby places).
- To answer your questions in chat, including by sending your question to an outside AI provider (Section 6).
- To let our chat read your pet's health record **only if you turn that on** for that pet. You can turn it off any time.
- To send you product news and tips by email **only if you opt in**.
- To understand how the app is used **only if you opt in** to analytics. [VERIFY: no analytics tool is active today; delete this line if none.]
- To keep VetApp secure, prevent abuse, fix problems, and follow the law.

## 5. Who we share information with

We do **not** sell your personal information, and we do **not** share it for cross-context behavioral advertising (targeted ads) [VERIFY before publication; this changes if we add ads or advertising SDKs]. We share information with service providers who work for us under contract:

| Provider | What they get | Where |
|---|---|---|
| Supabase | Database, sign-in, storage of attachments and photos | [Region: VERIFY] |
| Vercel | App server hosting | [VERIFY] |
| Groq (AI provider) | Text of your questions and documents, audio for transcription, images for analysis | [VERIFY: country and contract terms] |
| OpenStreetMap services (Nominatim, map tiles, Overpass) | An address you type (to find coordinates); your IP address and map areas requested; a grid-cell center, not your exact location | [VERIFY] |
| Google (Firebase App Distribution) | Test versions only: tester's email | [VERIFY] |

We may also disclose information if the law requires it, to protect people's safety, or in a merger or sale of the company (we would tell you).

Your data may be processed in the United States and in other countries, including the European Union. [VERIFY with counsel: company established in Italy, so EU data protection rules may also apply to our processing.]

## 6. How we use AI

VetApp's chat uses an artificial intelligence (AI) system run by an outside provider. Answers are generated by AI and are labeled that way in the app. Before sending your text to the provider, our system removes some personal details it can recognize, such as emails, phone numbers, and street addresses. It can't catch everything, for example a person's name in the middle of a sentence. Images and audio are sent as they are. Only share what you're comfortable sending. [Reviewer note: two calls currently send a health-record summary without the filter; see register item 28. Do not claim the record is filtered until fixed.]

AI can be wrong. It does not replace a veterinarian. See the AI and Veterinary Notice.

## 7. How long we keep information

| Information | How long |
|---|---|
| Account and pet profiles | Until you delete your account [procedure: VERIFY] |
| Health records and documents | Until you remove them or delete your account |
| Chat | [TBD] |
| Walk routes | [TBD; location data can reveal habits and home address] |
| Reports and votes | Pseudonym and votes deleted 12 months after the report closes; the content stays without your name [VERIFY] |
| Server logs | [TBD] |
| Proof of your consent choices | As long as needed to show we followed your choices [VERIFY] |

We may keep some information longer if the law requires it or for security, and then only what's needed.

## 8. Your choices

- **Consents:** change your marketing, analytics, and pet health-record consents any time in **Settings → Permissions & consents**.
- **Email:** click "unsubscribe" in any marketing email; we stop within 10 business days (usually sooner).
- **Phone permissions:** change them in your phone's settings.
- **Delete your account:** in the app under **Settings → [Delete account]** [VERIFY: required by Apple and Google; must work inside the app] or on our web page [URL VERIFY]. Deleting removes your account and the data tied to it, except what we must keep by law or for security, as described in Section 7.
- **Do Not Track / Global Privacy Control:** our app does not track you across other sites or apps. We treat a Global Privacy Control signal as an opt-out of sale and sharing, which we don't do anyway. [VERIFY: if a website exists with advertising, update.]

## 9. Your privacy rights by state

Depending on where you live, you may have the rights below. We offer them to **all U.S. users**, whether or not the law of your state strictly requires it. To make a request, write to [privacy@example.com] or use **Settings → Contact us** in the app. We may ask you to confirm your identity (for example, by replying from your account email). You may use an authorized agent; we may ask for proof they're authorized.

**How fast we respond:** within **45 days**; we can extend once by up to 45 more days if we tell you why. Opt-out requests: as soon as feasible and within 15 business days. If we deny a request, we'll tell you why. In states that give you a right to appeal, you can appeal by replying to our decision with the word "Appeal"; we'll respond within 60 days [VERIFY: appeal timelines vary by state; many states say 45–60 days]. You won't be treated worse for using your rights.

| Right | What it means | States |
|---|---|---|
| Know / access | Get the categories and specific pieces of information we have about you and how we use and share them | CA, VA, CO, CT, UT, TX, OR and other states [VERIFY] |
| Delete | Ask us to delete your information (with legal exceptions) | CA, VA, CO, CT, UT, TX, OR and others |
| Correct | Ask us to fix inaccurate information | CA, VA, CO, CT, TX, OR and others (not Utah) [VERIFY] |
| Portability | Get your information in a usable format | VA, CO, CT, UT, TX, OR and others; in CA as part of the right to know |
| Opt out of sale / sharing / targeted ads / profiling | Tell us not to sell or share your information, or use it for targeted ads or profiling with significant effects | CA, VA, CO, CT, UT (sale and targeted ads), TX, OR and others. We don't do these things today |
| Limit use of sensitive information | Limit use of sensitive information to what's needed to give you the service | CA. We use sensitive information (precise location) only to provide the service [VERIFY] |
| Consent for sensitive information | We ask for your permission before processing sensitive data such as precise location | VA, CO, CT, TX, OR and others (not CA, which uses the "limit" right) [VERIFY] |
| No retaliation | We won't treat you differently for using these rights | All |

**California residents:** The table below describes the categories of personal information we collected in the last 12 months, using the categories in California law. [VERIFY with counsel; fill from the actual data inventory.]

| California category | Do we collect it? | Why | Sold or shared? |
|---|---|---|---|
| Identifiers (email, name, IP address, device ID) | Yes | Account, security, service | No |
| Customer records / account details | Yes | Account, subscription | No |
| Commercial information (plan chosen) | Yes | Subscription | No |
| Internet or app activity (app use, logs) | Yes | Operate and secure the service [analytics only if you opt in] | No |
| **Precise geolocation** (sensitive) | Yes, if you allow it | Nearby places, walks | No |
| Audio, electronic, visual (voice messages, photos, videos) | Yes | Chat transcription, pet profiles | No |
| Inferences | [VERIFY: none / limited] | | No |
| Sensitive information other than location | [Not intentionally; may appear in documents or chat you upload] | | No |

California's "Shine the Light" law: we don't disclose personal information to third parties for their own direct marketing. [VERIFY]

**Texas, and other states that require specific notices:** [If we ever sell sensitive personal data, Texas requires the notice "NOTICE: We may sell your sensitive personal data." We do not sell it.] [VERIFY the exact current wording before any use.]

## 10. Security

We use reasonable technical and organizational measures to protect your information. No system is 100% secure. If there is a breach that affects you, we will notify you as required by law.

## 11. Changes to this policy

If we make material changes, we'll tell you in the app or by email before they take effect, and update the date above. The privacy summary you accept at sign-up is replaced by a new version when the policy changes materially.

## 12. Contact

[Company legal name], [12 Main St, City, ST 00000, USA]. Email: [privacy@example.com]. In the app: Settings → Contact us.

---

**Reviewer notes (delete before publishing):**
1. CalOPPA requires this policy to be easy to find and to state its effective date, how users learn about changes, and how Do Not Track signals are handled (included above).
2. The "Do Not Sell or Share" link is required only if we sell or share. Today the answer appears to be no; recheck with every new SDK, ad, or analytics tool.
3. Apple 5.1.2(i): before sending personal data to a third-party AI, we must say so and get explicit permission. See 04_consensi (id `privacy_policy` text and the chat first-use consent).
4. Do not claim "anonymized," "de-identified," or "HIPAA compliant." Do not say we are "compliant with" any specific law without counsel review.
5. Retention, appeal timeline, and data-inventory fields are placeholders.
