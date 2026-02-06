Mark a Taskmaster task as done and check if a blog article should be generated.

Task ID: $ARGUMENTS

## Process

1. **Complete the task:**
   ```
   task-master set-status --id=$ARGUMENTS --status=done
   ```

2. **Check blog series:** Read `docs/blog/SERIES.md` and find which blog part includes this task.

3. **Check if all tasks for that part are done:**
   - Run `task-master show <id>` for each task in the blog part
   - If ALL tasks for the part have status `done`, proceed to step 4
   - If some tasks are still pending/in-progress, report progress ("Part N: 2/3 tasks done")

4. **If part is ready, generate the article:**
   - Follow the `/blog` command process
   - Write the draft in `docs/blog/NNN-slug.md`
   - Update SERIES.md status to `draft`

5. **Show summary:**
   - Task completed
   - Blog part progress (e.g., "Part 5: 2/2 tasks done — article draft generated")
   - Next task suggestion via `task-master next`
