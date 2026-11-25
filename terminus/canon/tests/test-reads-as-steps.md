---
id: test-reads-as-steps
applies_to:
  - tests
territory:
  - "**/*_test.go"
---

## statement

A test body reads top to bottom as the steps it takes and the facts it checks. Each case is its own named subtest
function, each value a check reads is bound to a named variable first, and each check is one testify `require` or
`assert` call on its own line. A test function declares no types.

## why

A reader learns what a test proves by reading it once. A table of anonymous structs looped through `t.Run` hides each
case behind field names, and `if a || !b { t.Errorf(...) }` makes the reader invert a condition to learn what the test
expects.

## discrimination

Flag a test that:

- declares a type inside a test function (`cases := []struct{...}`, `steps := []struct{...}`)
- loops over a table of cases and calls `t.Run` in the loop instead of binding one named function per case
- checks with `if ... { t.Errorf(...) }` or `t.Fatalf` instead of a testify call
- joins two checks in one condition (`a || !b`)
- nests a call inside another call's or a check's arguments instead of binding it to a named variable first
- repeats a type assertion (`pressed.(zenModel)`) instead of binding its result once

## example

Bad:

    cases := []struct {
        name      string
        statusMsg tea.Msg
        wantShown string
    }{ ... }
    for _, testCase := range cases {
        t.Run(testCase.name, func(t *testing.T) {
            ...
            if strings.Contains(shown, "No code block to copy.") || !strings.Contains(shown, testCase.wantShown) {
                t.Errorf("screen = %q, want %q in place of the copy status", shown, testCase.wantShown)
            }
        })
    }

Good:

    func agentStatusReplacesCopyStatus(t *testing.T) {
        model := modelShowingCopyStatus(t)
        updated, _ := model.Update(agentStatusMsg{status: AgentWorking})
        screen := updated.(zenModel).screen()
        shown := ansi.Strip(screen)
        require.NotContains(t, shown, "No code block to copy.")
        require.Contains(t, shown, "Working...")
    }

## boundary

Do not flag a type declared at package level in a test file (a fake, a fixture), or a loop that applies the same one
check to every item of a list of plain values, as long as no item carries its own expected result. Do not flag a
golden test that finds its cases as folders or files on disk at run time and compares each to the expected output
stored beside it, since a new case is added by capturing data, not by writing code.
