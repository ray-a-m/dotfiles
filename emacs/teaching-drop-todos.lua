-- Teaching documents carry their own task headings: a quiz keeps the task
-- that made it, a syllabus keeps its revision notes.  Those are mine, not
-- the student's, so no todo subtree reaches the PDF or the DOCX.
--
-- pandoc's org reader knows TODO and DONE, and marks them as a Span with
-- the class "todo" or "done".  It does not know NEXT or CONTINUING: those
-- live in the Emacs config, which pandoc never reads, so they arrive as
-- plain text and need the name list below.  Keep that list in step with
-- org-todo-keywords.
--
-- A todo heading takes its whole subtree with it: every block up to the
-- next heading at the same level or above.

local keywords = {
  TODO = true, NEXT = true, CONTINUING = true, DONE = true,
}

local function heading_is_todo(header)
  local first = header.content[1]
  if not first then return false end
  if first.t == "Span" then
    for _, class in ipairs(first.classes) do
      if class == "todo" or class == "done" then return true end
    end
  end
  -- A keyword pandoc does not know stays a bare word at the front.
  return first.t == "Str" and keywords[first.text] == true
end

function Pandoc(doc)
  local kept = {}
  local dropping = nil               -- level of the todo heading being dropped
  for _, block in ipairs(doc.blocks) do
    if block.t == "Header" then
      if dropping and block.level <= dropping then dropping = nil end
      if not dropping and heading_is_todo(block) then dropping = block.level end
    end
    if not dropping then kept[#kept + 1] = block end
  end
  doc.blocks = kept
  return doc
end
