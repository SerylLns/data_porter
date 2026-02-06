Write the next blog article for the DataPorter series.

Topic/title hint: $ARGUMENTS

## Process

1. **Read the series plan** at `docs/blog/SERIES.md` to identify which part this is and what it should cover.

2. **Gather context:**
   - `task-master list` to see completed tasks
   - `git log --oneline -20` for recent commits
   - Read the source files listed in the series plan for this part
   - Read any previous articles in `docs/blog/` to maintain continuity

3. **Write the article** in `docs/blog/NNN-slug.md` (NNN = part number, zero-padded).

4. **Mandatory article structure:**

```markdown
---
title: "Building DataPorter #N — <Title>"
series: "Building DataPorter - A Data Import Engine for Rails"
part: N
tags: [ruby, rails, rails-engine, gem-development, <2-3 topic tags>]
published: false
---

# <Title>

> One-line summary of what the reader will learn.

## Context

Where we are in the series (1-2 sentences). Link to previous article.
What we'll build in this article (clear scope).

## The problem

Why do we need this? Real-world scenario. Keep it short (3-5 sentences).

## What we're building

Show the end result first: a code snippet, a diagram, or a usage example.
The reader should immediately understand where we're going.

## Implementation

### Step 1 — <Name>

Explain the WHY, then show the code.

\`\`\`ruby
# path/to/file.rb
<focused snippet, not full file>
\`\`\`

Brief explanation of what this does and why we chose this approach.

### Step 2 — <Name>

(repeat pattern: WHY -> code -> explain)

### Step 3 — <Name>

(repeat)

## Decisions & tradeoffs

| Decision | We chose | Over | Because |
|----------|----------|------|---------|
| ... | ... | ... | ... |

## Testing it

Show how to verify this works (spec snippet or console output).

\`\`\`ruby
# spec/...
\`\`\`

## Recap

3-4 bullet points: what we built, what we learned.

## Next up

One paragraph teasing the next article in the series. End with a hook.

---

*This is part N of the series "Building DataPorter". [Previous: ...](#) | [Next: ...](#)*
*Code: [GitHub repo link]*
```

5. **Writing rules:**
   - 5-8 minute read (~1000-1500 words)
   - Max 3-4 implementation steps per article
   - Code snippets: focused, 5-25 lines each (never full file dumps)
   - Every snippet has a file path comment on line 1
   - Explain decisions as "We chose X over Y because Z"
   - Use the actual code from the codebase (not made-up examples)
   - Conversational but technical tone: "Let's...", "Here's why..."
   - English only
   - No emojis in prose (OK in front matter tags)

6. **After writing:**
   - Update the article status in `docs/blog/SERIES.md` to `draft`
   - Show: title, word count, reading time, and the decisions table
   - Suggest 2-3 improvements or missing points
