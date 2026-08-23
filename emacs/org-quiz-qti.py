#!/usr/bin/env python3
"""Convert an org-authored multiple-choice quiz into a Canvas QTI 1.2 zip.

Called by `rm/teaching-qti' in init.el; usable by hand for the same job:

    org-quiz-qti.py SRC OUT.zip "Quiz Title" [--no-shuffle] [--merge]

The quiz format is what the model writes into the llm block:

    /1./ Question text
    a) distractor
    *b)* correct answer
    c) distractor
    d) distractor

The correct answer is the one option whose label carries org emphasis:
*b)* or /b)/. The two marks mean the same thing here, because the model
picks whichever it likes and both read as "this one" on the page. The
mark must open and close with the same character and must cover the
letter and the parenthesis together. Stems also parse as `1.' or `*1.*'.

Canvas shuffles the answers per student unless --no-shuffle. Shuffling
turns itself off when an option refers to the others by position ("all of
the above"), because shuffling breaks those.

Every question must have one marked answer and at least two options, and
no stem number may repeat. Anything else is an error, not a guess: a
half-parsed quiz that imports cleanly is worse than one that refuses to
build.

--merge lifts the repeat-number rule for one caller: the elisp that feeds
this script every llm block of a quiz document at once. A quiz grows over
several exchanges, so the same stem number arrives again when the model
revises a question. Under --merge the last copy of a number wins and the
questions sort by number, which makes the whole document one quiz. Without
the flag a repeated number still stops the build, because in a hand-written
file it means two quizzes in one file.
"""
import html
import os
import re
import sys
import zipfile

Q_RE = re.compile(r'^[/*]?(\d+)\.[/*]?\s+(.*)$')
OPT_RE = re.compile(r'^([*/]?)([a-h])\)([*/]?)\s+(.*)$')
ITALIC_RE = re.compile(r'(?<![\w/])/([^/\n]+?)/(?![\w/])')
BOLD_RE = re.compile(r'(?<![\w*])\*([^*\n]+?)\*(?![\w*])')
POSITIONAL_RE = re.compile(
    r'\b(all|none|both|any) of the (above|below|these)\b'
    r'|\b[a-h] and [a-h]\b'
    r'|\bboth [a-h] and [a-h]\b',
    re.I)


def org_to_html(text):
    """Minimal org emphasis -> HTML. Escapes first so markup survives."""
    t = html.escape(text, quote=False)
    t = ITALIC_RE.sub(r'<em>\1</em>', t)
    t = BOLD_RE.sub(r'<strong>\1</strong>', t)
    return t


def parse(path):
    questions = []
    cur = None
    with open(path, encoding='utf-8') as fh:
        for raw in fh:
            line = raw.rstrip('\n').strip()
            m = OPT_RE.match(line)          # before the heading check: *b)* starts with *
            if m and cur is not None:
                pre, label, post, body = m.groups()
                cur['options'].append({
                    'label': label,
                    'text': body,
                    # *b)* and /b)/ both mark the answer. A lone mark on
                    # one side is emphasis that ran on from the line
                    # before, not an answer.
                    'correct': bool(pre) and pre == post,
                })
                continue
            m = Q_RE.match(line)
            if m:
                cur = {'num': int(m.group(1)), 'text': [m.group(2)], 'options': []}
                questions.append(cur)
                continue
            if cur is None:
                continue
            if not line:
                continue
            if line.startswith(('*', '#+', ':')):   # heading, block delimiter, drawer
                cur = None
                continue
            if not cur['options']:
                cur['text'].append(line)            # a stem that wrapped
    for q in questions:
        q['text'] = ' '.join(q['text'])
    return questions


def merge(questions):
    """Fold repeated stem numbers into one question, last copy winning.

    Returns the questions in number order and the numbers that were
    replaced, so the caller can say what it dropped.
    """
    by_num = {}
    replaced = []
    for q in questions:
        if q['num'] in by_num:
            replaced.append(q['num'])
        by_num[q['num']] = q
    return [by_num[n] for n in sorted(by_num)], sorted(set(replaced))


def validate(questions):
    problems = []
    if not questions:
        problems.append('no questions found')
    seen = {}
    for q in questions:
        n = sum(1 for o in q['options'] if o['correct'])
        if n != 1:
            problems.append(f"Q{q['num']}: {n} answers marked correct (want exactly 1)")
        if len(q['options']) < 2:
            problems.append(f"Q{q['num']}: only {len(q['options'])} options")
        seen[q['num']] = seen.get(q['num'], 0) + 1
    for num, count in sorted(seen.items()):
        if count > 1:
            problems.append(
                f"Q{num}: appears {count} times — more than one quiz here. "
                "Put point in the block you want and export that.")
    return problems


def positional(questions):
    """Questions whose options name each other by position."""
    return [q['num'] for q in questions
            if any(POSITIONAL_RE.search(o['text']) for o in q['options'])]


def item_xml(q, quiz_id):
    ident = f'{quiz_id}_q{q["num"]:03d}'
    aids = [str(1000 + q['num'] * 10 + i) for i in range(len(q['options']))]
    correct = aids[[o['correct'] for o in q['options']].index(True)]
    labels = []
    for aid, opt in zip(aids, q['options']):
        labels.append(
            f'          <response_label ident="{aid}">\n'
            f'            <material>\n'
            f'              <mattext texttype="text/html">'
            f'{html.escape("<p>" + org_to_html(opt["text"]) + "</p>")}</mattext>\n'
            f'            </material>\n'
            f'          </response_label>'
        )
    body = html.escape('<p>' + org_to_html(q['text']) + '</p>')
    return f'''    <item ident="{ident}" title="Question {q['num']}">
      <itemmetadata>
        <qtimetadata>
          <qtimetadatafield>
            <fieldlabel>question_type</fieldlabel>
            <fieldentry>multiple_choice_question</fieldentry>
          </qtimetadatafield>
          <qtimetadatafield>
            <fieldlabel>points_possible</fieldlabel>
            <fieldentry>1.0</fieldentry>
          </qtimetadatafield>
          <qtimetadatafield>
            <fieldlabel>original_answer_ids</fieldlabel>
            <fieldentry>{','.join(aids)}</fieldentry>
          </qtimetadatafield>
          <qtimetadatafield>
            <fieldlabel>assessment_question_identifierref</fieldlabel>
            <fieldentry>{ident}_aq</fieldentry>
          </qtimetadatafield>
        </qtimetadata>
      </itemmetadata>
      <presentation>
        <material>
          <mattext texttype="text/html">{body}</mattext>
        </material>
        <response_lid ident="response1" rcardinality="Single">
          <render_choice>
{chr(10).join(labels)}
          </render_choice>
        </response_lid>
      </presentation>
      <resprocessing>
        <outcomes>
          <decvar maxvalue="100" minvalue="0" varname="SCORE" vartype="Decimal"/>
        </outcomes>
        <respcondition continue="No">
          <conditionvar>
            <varequal respident="response1">{correct}</varequal>
          </conditionvar>
          <setvar action="Set" varname="SCORE">100</setvar>
        </respcondition>
      </resprocessing>
    </item>'''


def build(questions, quiz_id, title, shuffle):
    items = '\n'.join(item_xml(q, quiz_id) for q in questions)
    assessment = f'''<?xml version="1.0" encoding="UTF-8"?>
<questestinterop xmlns="http://www.imsglobal.org/xsd/ims_qtiasiv1p2" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.imsglobal.org/xsd/ims_qtiasiv1p2 http://www.imsglobal.org/xsd/ims_qtiasiv1p2p1.xsd">
  <assessment ident="{quiz_id}" title="{html.escape(title)}">
    <qtimetadata>
      <qtimetadatafield>
        <fieldlabel>cc_maxattempts</fieldlabel>
        <fieldentry>1</fieldentry>
      </qtimetadatafield>
    </qtimetadata>
    <section ident="root_section">
{items}
    </section>
  </assessment>
</questestinterop>
'''
    meta = f'''<?xml version="1.0" encoding="UTF-8"?>
<quiz identifier="{quiz_id}" xmlns="http://canvas.instructure.com/xsd/cccv1p0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://canvas.instructure.com/xsd/cccv1p0 https://canvas.instructure.com/xsd/cccv1p0.xsd">
  <title>{html.escape(title)}</title>
  <description></description>
  <shuffle_answers>{'true' if shuffle else 'false'}</shuffle_answers>
  <scoring_policy>keep_highest</scoring_policy>
  <hide_results></hide_results>
  <quiz_type>assignment</quiz_type>
  <points_possible>{float(len(questions))}</points_possible>
  <require_lockdown_browser>false</require_lockdown_browser>
  <require_lockdown_browser_for_results>false</require_lockdown_browser_for_results>
  <require_lockdown_browser_monitor>false</require_lockdown_browser_monitor>
  <allowed_attempts>1</allowed_attempts>
  <one_question_at_a_time>false</one_question_at_a_time>
  <cant_go_back>false</cant_go_back>
  <available>false</available>
  <one_time_results>false</one_time_results>
  <show_correct_answers_last_attempt>false</show_correct_answers_last_attempt>
  <only_visible_to_overrides>false</only_visible_to_overrides>
  <module_locked>false</module_locked>
</quiz>
'''
    manifest = f'''<?xml version="1.0" encoding="UTF-8"?>
<manifest identifier="{quiz_id}_manifest" xmlns="http://www.imsglobal.org/xsd/imsccv1p1/imscp_v1p1" xmlns:lom="http://ltsc.ieee.org/xsd/imsccv1p1/LOM/resource" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.imsglobal.org/xsd/imsccv1p1/imscp_v1p1 http://www.imsglobal.org/profile/cc/ccv1p1/ccv1p1_imscp_v1p2_v1p0.xsd">
  <metadata>
    <schema>IMS Content</schema>
    <schemaversion>1.1.3</schemaversion>
  </metadata>
  <organizations/>
  <resources>
    <resource identifier="{quiz_id}" type="imsqti_xmlv1p2">
      <file href="{quiz_id}/{quiz_id}.xml"/>
      <dependency identifierref="{quiz_id}_meta"/>
    </resource>
    <resource identifier="{quiz_id}_meta" type="associatedcontent/imscc_xmlv1p1/learning-application-resource" href="{quiz_id}/assessment_meta.xml">
      <file href="{quiz_id}/assessment_meta.xml"/>
    </resource>
  </resources>
</manifest>
'''
    return assessment, meta, manifest


def main():
    argv = [a for a in sys.argv[1:] if not a.startswith('--')]
    shuffle = '--no-shuffle' not in sys.argv[1:]
    merging = '--merge' in sys.argv[1:]
    if len(argv) < 2:
        print(__doc__.strip(), file=sys.stderr)
        sys.exit(2)
    src, out = argv[0], argv[1]
    title = argv[2] if len(argv) > 2 else os.path.splitext(os.path.basename(out))[0]
    quiz_id = re.sub(r'[^a-z0-9]+', '_', title.lower()).strip('_') or 'quiz'

    questions = parse(src)
    replaced = []
    if merging:
        questions, replaced = merge(questions)
    problems = validate(questions)
    if problems:
        print('qti: refused to build —', file=sys.stderr)
        for p in problems:
            print('  ' + p, file=sys.stderr)
        sys.exit(1)

    note = ''
    if shuffle:
        pos = positional(questions)
        if pos:
            shuffle = False
            note = (' — position-dependent options in Q'
                    + ', Q'.join(str(n) for n in pos))

    assessment, meta, manifest = build(questions, quiz_id, title, shuffle)
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr('imsmanifest.xml', manifest)
        z.writestr(f'{quiz_id}/{quiz_id}.xml', assessment)
        z.writestr(f'{quiz_id}/assessment_meta.xml', meta)

    if replaced:
        note += (' — revised Q' + ', Q'.join(str(n) for n in replaced))
    print(f'qti: {len(questions)} questions, shuffle '
          f'{"on" if shuffle else "off"}{note}')
    for q in questions:
        key = next(o['label'] for o in q['options'] if o['correct'])
        print(f'  Q{q["num"]:>2}  key={key}  ({len(q["options"])} options)')


if __name__ == '__main__':
    main()
