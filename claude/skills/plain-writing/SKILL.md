---
name: plain-writing
description: Checks and rewrites prose against "Writing and tone" in ~/.claude/CLAUDE.md and a catalogue of rhetorical tics. Use before sending or saving any text a person reads, which covers every reply, HTML and Markdown docs, UI text such as labels, messages, tooltips and errors, code comments, commit messages, PR descriptions, tickets, and review findings. Also use when the user asks to make text plainer.
---

# Plain writing

Check a draft against "Writing and tone" in `~/.claude/CLAUDE.md`, then against the tics below.
Rewrite each hit in place and send the rewritten text.

## Steps

1. Read the draft one sentence at a time. For each sentence, name the new fact it gives the
   reader. Delete a sentence that gives none.
2. Find the actor and the action in each sentence. Make the actor the subject and the action the
   verb.
3. Rewrite every noun stack and every phrase you coined as a short clause with a verb.
4. Match each sentence against the tic table. Rewrite each match with the fix in its row.
5. Put the most important point of each paragraph and each list first.

The check is done when every sentence carries one new fact, has an actor doing a verb, and
matches no row of the table.

## Actor and verb

The person or thing that acts is the subject. Its action is the verb.

| Write | In place of |
|---|---|
| Declan merged a change on 2 Oct. | A change was merged by Declan on 2 Oct. |
| The duck asked for grapes. | A request for grapes was made upon the duck's arrival. |
| The script refits the population. | The refit of the population happens in the script. |

Two forms hide the actor: an action turned into a noun ("a request was made", "the refit of
the population") and a passive verb ("was merged by"). Turn each back into an actor doing a
verb. A passive verb stays only when the actor is unknown.

## Plain words

Write the words a colleague says out loud. A stack of three or more nouns, or a phrase you
made up, becomes a short clause with a verb.

| Write | In place of |
|---|---|
| The duck asked if the lemonade stand had grapes. | The duck made a grape availability request at the beverage retailer. |
| The awareness file lists the label. | a label's awareness entry |
| One pass reads the video and the transcript. | vision-and-transcript pass |
| The filter drops a block shorter than the minimum length. | length floor drops a block |
| One model fits all the data. | single-model fit |

## One fact per sentence

Each sentence states one fact the reader needs, with the most important point first. Delete a
sentence that sounds deep and states nothing: "The question of grapes remains open until the
seller's answer closes it." Split a sentence that carries two or three side points, and cut the
side points the reader has no use for.

## Tics

Each tic puts a plain fact in a rhetorical form. The fix states the fact.

| Tic | Example | Fix |
|---|---|---|
| Negation-first reveal | It is not a wrong answer. It is a non-answer. | State the claim: "The reply does not answer the question." |
| Significance designation | It is the leg that answers the actual question. | State what the item shows and let the reader weigh it: "Leg 4 measures time per token." |
| Abstraction agency | Median hides it. / The table shows it. | Name the data or the person: "The median, 210 ms, includes the three 2 s outliers." |
| Deferred noun | Five of those six rows are one cluster. The sixth is not. | Name the thing at first mention: "Rows 1 to 5 hit the warm cache. Row 6 is a cold start." |
| Coy or thesis-shaped header | What "exhausted" means / The one gap that does clear the bar | Name the topic: "Retry exhaustion" / "Missing index on requestId". |
| Aphoristic closer | It is the kind of number that looks like evidence and is not. | End on the last fact. Delete the closer. |
| Straw-man knockdown | "It thinks twice as long" is the obvious reading, and it is wrong. | State the correct reading only: "It writes twice as many tokens at the same speed." |
| Fragment cadence | Six legs. One GPU, one server build, one sampler, one question set. | Write the sentence: "All six legs ran on one GPU, server build, sampler, and question set." |
| Dressed metaphor | That is information loss wearing the costume of a style fix. | Say the literal event: "The change deletes the line numbers." |
| Label-first framing | The short version: … / Bottom line: … / The catch: … | Start with the content. Delete the label that names the sentence's role. |

A bold lead-in on a list item that names the item stays: "**Prod server.** It listens on port
5432."
