---
name: study-plan
description: >-
  Creates structured study plans from any input — job postings, skill ideas, pasted
  conversations, articles, or freeform thoughts about what to learn. Analyzes the input
  against the user's current skills, identifies gaps, and generates a phased learning path
  with Coursera courses (premium access), free resources (YouTube, blogs, official docs),
  hands-on projects, and clear milestones. Use when user says "study plan", "learning path",
  "prepare for this role", or "create a study plan".
user-invocable: true
disable-model-invocation: false
---

# Study Plan Creator

Generate structured, phased study plans from any input — job postings, skill ideas, pasted conversations, articles, or freeform thoughts. Analyzes skill gaps, sources real learning resources (prioritizing Coursera premium), and produces a complete learning roadmap saved to `/mnt/syno/career/study-plans/`.

## Important

- **Coursera premium access is available** — always prioritize Coursera courses and specializations. These are not free-tier-only; full paid content is accessible.
- **All resources must be real** — never fabricate course names, URLs, or instructors. Use WebSearch to verify every resource exists before including it.
- **The user builds with AI-assisted development (Claude Code)** — they understand system design, APIs, integration patterns, and automation architecture. The gap is typically in writing/reading code syntax independently, not in conceptual understanding. Calibrate the plan accordingly.
- **Output location:** Always write to `/mnt/syno/career/study-plans/`
- **File naming:** Use kebab-case derived from the context: `{company}-{role-summary}.md` for job postings, `{topic-summary}.md` for general learning goals (e.g., `kubernetes-platform-engineering.md`, `python-backend-fundamentals.md`)

## Instructions

### Step 1: Receive and Interpret the Input

The user may provide any of the following:

- **A job posting** (pasted text or URL) — the most structured input
- **A pasted conversation** (e.g., from Slack, a meeting, a chat) — extract the learning goals/skills discussed
- **An article or blog post** (pasted or URL) — identify the skills/technologies covered that the user wants to learn
- **Freeform thoughts or ideas** (e.g., "I want to learn Kubernetes and get into platform engineering") — treat as a goal statement
- **A mix of the above** — synthesize all inputs into a coherent learning target

If they provide a URL, use WebFetch to retrieve the content.

**For job postings**, extract and organize:
- **Company name** and **Role title**
- **Core responsibilities** (list each one)
- **Required skills/experience** (list each with stated experience level)
- **Nice-to-have skills** (list each)
- **Tech stack** (every tool, language, framework, service mentioned)
- **Domain context** (industry, regulatory requirements, team structure)

**For non-job-posting input**, extract and organize:
- **Learning goal** — what the user wants to be able to do (synthesize from their input)
- **Target skills** — every specific technology, tool, language, framework, or concept mentioned or implied
- **Domain context** — industry, role type, or career direction if apparent
- **Ambiguities** — anything unclear that needs clarifying before building the plan

If the input is vague or incomplete, ask clarifying questions before proceeding (see Step 2). Do not guess at requirements — ask.

### Step 2: Assess Current Skills

Ask the user as many questions as needed to accurately gauge their current level against every identified skill/requirement. **Do not rush this step.** An inaccurate assessment leads to a bad plan — it's better to ask 12 questions across 3 rounds than to guess.

Use AskUserQuestion with up to 4 questions per call (the tool's limit). If more questions are needed, make multiple calls. Keep going until you have a confident read on every skill area.

**Always ask (minimum baseline):**

1. **Current comfort with the primary language/framework** — calibrate with concrete options (e.g., "Can't read/write at all", "Can read basic code", "Can write simple scripts", "Comfortable independently")
2. **Experience with the primary cloud/infra platform** — map what they know vs what's required
3. **Study time availability** — hours per week
4. **Timeline pressure** — "Apply in 2-4 weeks", "1-2 months", "2-3 months", "No rush, building skills"

**Then ask about every skill area where the gap is ambiguous.** Cover:
- Each major technology in the requirements (don't assume — ask)
- Adjacent skills that might transfer (e.g., "You know GCP Cloud Functions — have you touched AWS Lambda at all?")
- Soft requirements (domain knowledge, team collaboration patterns, on-call experience)
- Learning style preferences if relevant ("Do you prefer video courses, reading docs, or hands-on projects?")

**Only skip questions for things you can confidently infer** from prior conversation context or the user's existing files (e.g., don't ask about REST APIs if their career-assessment.md shows 25+ system integrations).

### Step 3: Build the Gap Analysis

Create a gap analysis table comparing every requirement against current skill level:

```markdown
## Gap Analysis

| Requirement | Current Level | Gap Size |
|---|---|---|
| Python 5+ years (FastAPI/Django) | Can't read/write independently | **Critical** |
| AWS (Lambda, ECS) | S3 only, strong GCP | **Large** |
| Terraform | Strong (Okta IaC) | Minimal |
```

Gap sizes: **Critical** (blocking, no foundation), **Large** (some conceptual overlap but no hands-on), **Medium** (conceptual understanding, needs specific tooling), **Small** (minor gap, quick to close), **Minimal/None** (already have this).

### Step 4: Design Phased Learning Path

Structure the plan into **5-8 phases** following these principles:

1. **Critical gaps first** — the phase order should prioritize blocking gaps that other skills depend on
2. **Phases overlap** — indicate which phases can run concurrently (e.g., "start when Phase 1 is at week 4")
3. **Each phase gets:**
   - A clear **goal statement** (one sentence)
   - **Primary path** — 1-3 Coursera courses/specializations (with links)
   - **Supplementary resources** — 2-5 free resources (YouTube, official docs, blogs, GitHub repos)
   - **Hands-on project** — a concrete project that bridges their existing skills with the new ones
   - **Milestone** — a blockquoted statement describing what "done" looks like for this phase

4. **Resource sourcing rules:**
   - Use **WebSearch** to find real Coursera courses for each topic. Search for: `Coursera [topic] course [year]`
   - Use **WebSearch** to find real free YouTube tutorials, blog posts, official docs
   - **Every resource must have a real URL** — verify with WebSearch
   - **Prefer well-known providers:** Coursera (DeepLearning.AI, IBM, Google, AWS, University of Michigan, Johns Hopkins, Duke, Stanford), YouTube (freeCodeCamp, Fireship, Tech With Tim, Traversy Media, NetworkChuck), Docs (official project docs), Blogs (Real Python, DigitalOcean tutorials)
   - **Include course provider/instructor** for credibility

5. **Phase design pattern:**

```markdown
## Phase N: [Topic] (Weeks X-Y)

**Goal:** [One sentence describing what they'll be able to do after this phase.]

[Optional: 1-2 sentences of context about why this matters or how their existing skills transfer.]

### Primary Path (Coursera)

**1. [Course Name](URL) — Provider**
- [What it covers and why it's relevant]

### Supplementary (Free)

- **[Resource Name](URL)** — [Type: YouTube/Docs/Blog] — [Brief description]

### Hands-On Project
> [Concrete project description that connects to their existing work or the target role]

### Milestone
> [What "done" looks like — a testable statement of capability]
```

### Step 5: Add Supporting Sections

After all phases, include:

**Resource Index** — Two tables summarizing all resources:
1. Coursera courses (with phase, provider)
2. Free resources (with phase, type)

**Daily Habit** — 2-3 small daily practices to start immediately regardless of phase (e.g., reading existing code, writing small snippets, keeping a learning log).

**Timeline Estimate** — Table showing each phase's duration and overlap windows.

**Advantages Section** — List what the user already brings that other candidates for this role likely won't have. This is important for motivation and for interview preparation. Reference concrete evidence from their background.

### Step 6: Write the File

Save the complete study plan to `/mnt/syno/career/study-plans/{filename}.md`

Use the appropriate document header based on input type:

**For job postings:**
```markdown
# Study Plan: [Role Title] — [Company]

Target role: **[Role Title]**, [Team/Department], [Company] ([Location])
Status: **[Timeline]** | [Study hours]
```

**For general learning goals:**
```markdown
# Study Plan: [Learning Goal Summary]

Goal: **[What the user wants to be able to do]**
Source: [Brief description of what prompted this — e.g., "conversation about platform engineering", "article on AIOps"]
Status: **[Timeline]** | [Study hours]
```

Use this document structure:

---

## Gap Analysis
[Table from Step 3]

---

## Phase 1: [Topic] (Weeks X-Y)
[Phase content from Step 4]

---

[... more phases ...]

---

## Resource Index
[Tables from Step 5]

---

## Daily Habit
[From Step 5]

---

## Timeline Estimate
[From Step 5]

---

## Your Advantages Going In
[From Step 5]
```

### Step 7: Review with User

After writing the file, provide a brief summary:
- Number of phases and total timeline
- The top 3 critical gaps and how the plan addresses them
- Ask if they want to adjust anything (add/remove phases, change resource preferences, adjust timeline)

## Troubleshooting

### Job posting is too vague
If the posting lacks specific tech stack details, use WebSearch to research the company's tech stack (check their engineering blog, job boards, LinkedIn). Fill in likely requirements based on the role type and industry.

### User's skill level is unclear
Default to the conservative assessment. It's better to include a phase they can skip quickly than to skip a phase they actually need.

### Can't find a good Coursera course for a topic
Fall back to: free YouTube courses > official documentation tutorials > well-known blog series. Note in the plan that this area has weaker structured learning options.

### Too many gaps — plan would be 12+ months
Group related skills into combined phases. Prioritize the 5-6 most critical gaps. Note remaining gaps as "post-hire learning" that can happen on the job.


## Directive: update-skill
When the user says "update-skill", read [references/update-skill.md](references/update-skill.md) and follow those instructions.
