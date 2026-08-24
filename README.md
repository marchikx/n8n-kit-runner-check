# n8n-kit-runner-check

The evidence behind [n8n-io/self-hosted-ai-starter-kit#146](https://github.com/n8n-io/self-hosted-ai-starter-kit/pull/146).

Two jobs, one workflow, one difference: the compose file.

- **baseline** downloads `docker-compose.yml` and `.env.example` from the starter kit's `main` and runs the workflow against it
- **patched** runs the same workflow against the compose file from the PR branch, which is committed here

The workflow is a manual trigger into a Code node set to Python:

```python
return [{"json": {"python_ran": True, "two_plus_two": 2 + 2}}]
```

`ci/run-check.sh` creates the owner account, imports the workflow and executes it through
the editor API, then prints the execution status and digs the message out of the raw
execution payload. Run it yourself with the `python-runner-check` workflow in Actions.
