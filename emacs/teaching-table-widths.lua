-- Give every table explicit column widths.
--
-- pandoc's org reader hands the writer width-less columns, and the LaTeX
-- writer then sets them as `l': a wide table (a semester schedule) runs
-- off the right margin instead of wrapping, and the page cuts what is
-- past it.  Here a narrow column (a week number, a date, a page count)
-- is set at its natural width, so it never wraps, and the prose columns
-- share the line that is left.

local stringify = pandoc.utils.stringify

-- One line of body text holds about this many characters, and a column
-- whose widest cell is no wider than SHORT counts as narrow.  Both are
-- measures of the same thing: characters across the line.
local LINE_CHARS = 80
local SHORT = 14

local function each_cell (tbl, fn)
  local function rows (rs)
    for _, row in ipairs(rs) do
      for i, cell in ipairs(row.cells) do fn(i, cell) end
    end
  end
  rows(tbl.head.rows)
  for _, b in ipairs(tbl.bodies) do rows(b.head); rows(b.body) end
  rows(tbl.foot.rows)
end

function Table (tbl)
  local n = #tbl.colspecs
  if n == 0 then return nil end
  -- A table that already states its widths keeps them.
  for _, spec in ipairs(tbl.colspecs) do
    if type(spec[2]) == 'number' then return nil end
  end

  local cell, word = {}, {}             -- longest cell, longest word
  for i = 1, n do cell[i], word[i] = 1, 1 end
  each_cell(tbl, function (i, c)
    if not cell[i] then return end      -- a spanning cell: no column of its own
    local s = stringify(c.contents)
    if #s > cell[i] then cell[i] = #s end
    for w in s:gmatch('%S+') do
      if #w > word[i] then word[i] = #w end
    end
  end)

  -- A table whose columns already fit across the line is left alone:
  -- pandoc sets it in `l' columns, which is tighter than anything
  -- stated widths can give it.
  local natural = n                     -- a separator per column
  for i = 1, n do natural = natural + cell[i] end
  if natural <= LINE_CHARS then return nil end

  -- The narrow columns take their natural width (one character of slack
  -- for the space the characters really occupy); the rest divide what
  -- remains in proportion to their longest cell, and no column falls
  -- below the longest word it has to hold.
  local width, held, free = {}, 0, 0
  for i = 1, n do
    if cell[i] <= SHORT then
      width[i] = (cell[i] + 1) / LINE_CHARS
      held = held + width[i]
    else
      free = free + cell[i]
    end
  end
  if free == 0 or held >= 0.9 then      -- narrow columns fill the line
    for i = 1, n do width[i] = cell[i] / (held * LINE_CHARS + free) end
  else
    for i = 1, n do
      if not width[i] then
        width[i] = math.max(cell[i] / free * (1 - held),
                            (word[i] + 1) / LINE_CHARS)
      end
    end
  end

  local specs = {}
  for i = 1, n do specs[i] = { tbl.colspecs[i][1], width[i] } end
  tbl.colspecs = specs
  return tbl
end
