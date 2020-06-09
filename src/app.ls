c = console.log

get-priority = (line) ->
    pattern = /^priority (\d+)$/
    priority = line.replace pattern, \$1 |> Number
    if isNaN priority then null else priority

get-post-jump = (line) ->
    pattern = /^post_jump (.+)$/
    post-jump = line.replace pattern, \$1
    if post-jump == line then null else post-jump

get-context = (line) ->
    pattern = /^context (.+)$/
    context = line.replace pattern, \$1
    if context == line then null else context

parse-snippet-line = (line) ->
    pattern = /^snippet (('(?<triggerQuoted>[^']+)')|(?<trigger>[^ ]+)) ("(?<name>[^"]+)")? (?<flags>[biwrtsmeA]+)?$/
    { groups } = pattern.exec(line) || { groups: null }

    if groups == null
        return null

    return
        flags: groups.flags |> flags-string-to-object
        trigger: groups.trigger || groups.triggerQuoted
        name: groups.name

flags-string-to-object = (flags-string) ->
    flags-object = {}
    for flag in <[b i w r t s m e A]>
        flags-object[flag] = flags-string.includes flag
    return flags-object

get-content = (source) ->
    content-lines = []
    for line in source / '\n'
        line-starts-with = -> line.trim-start().starts-with "#it "
        if line-starts-with \snippet
            continue
        if line-starts-with \priority
            continue
        if line-starts-with \post_jump
            continue
        if line-starts-with \context
            continue
        if line.trim() == \endsnippet
            continue
        content-lines.push line

    return content-lines.join '\n'
    
extract-snippet = (source) ->
    priority = null
    post-jump = null
    context = null
    trigger = ''
    name = ''
    flags =
        b: false, t: false
        i: false, s: false
        w: false, m: false
        r: false, e: false
        A: false
    content = ''
    
    seen =
        post-jump: false
        priority: false
        context: false
        snippet-line: false
        endsnippet: false

    for line in source / '\n'
        line .= trim!
        if line == 'endsnippet'
            break
        if not seen.snippet-line and parse-snippet-line(line) != null
            # other directives must be set before the snippet line so mark everything else as seen too
            seen.post-jump = seen.priority = seen.context = seen.snippet-line = true
            { trigger, name, flags } = parse-snippet-line line
        else if not seen.priority and get-priority(line) != null
            priority = get-priority line
            seen.priority = true
        else if not seen.context and get-context(line) != null
            context = get-context line
            seen.context = true
        else if not seen.post-jump and get-post-jump(line) != null
            post-jump = get-post-jump line
            seen.post-jump = true
            
    
    content = get-content source
    snippet = {priority, post-jump, flags, trigger, name, context, content}
    c \parsed, snippet
    return snippet

escape-quotes = (string) ->
    string.replace /(?<!\\)"/g, '\\\"'

generate-snippet = ({priority, post-jump, flags, trigger, name, context, content}) ->
    priority-string = if priority != null 
        then "priority #priority\n" 
        else ''
    context-string = if context != null
        then "context \"#{context |> escape-quotes}\"\n"
        else ''
    post-jump-string = if post-jump != null
        then "post_jump \"#{post-jump |> escape-quotes}\"\n"
        else ''
    flags-string = Object.entries(flags)
        .filter(([k, v]) -> v) # Filter by value (is the flag present?)
        .map(([k,v]) -> k) # Map by key (get the flag name, not true or false)
        .join('') # Join into a string ([\w, \r] -> \wr )
    
    (priority-string + context-string + post-jump-string +
    """
    snippet '#trigger' "#name" #flags-string
    #content
    endsnippet
    """).trim!

generate-tabstop = ({ position, default-value, substitution }) ->
    if default-value
        "${#position:#default-value}"
    else if substitution and substitution.length == 2
        [search, replace] = substitution.map (v) -> v.replace /(?<!\\)\//g '\\/'
        "${#position/#search/#replace/g}"
    else if position
        "$#position"

generate-code-embed = ({language, content}) ->
    tag = switch language
        | \shell => ''
        | \python => \!p
        | \vimscript => \!v
        default null
    
    if tag is null
        return null
    
    """`#tag
    \t#content
    `"""

generate-tabstop-reference = ({ language, position }) ->
    switch language
    | \python =>
        "t[#position]"
    default
        null

generate-content-assignement = ({ language }) ->
    switch language
    | \python =>
        'snip.rv = '
    default
        null

generate-trigger-regex-group-reference = ({ language, position }) ->
    switch language
    | \python =>
        "match.group(#position)"
    default
        null
    

if typeof window != \undefined
    window <<< {
        generate-snippet
        extract-snippet
        generate-tabstop
        generate-tabstop-reference
        generate-trigger-regex-group-reference
        generate-content-assignement
        generate-code-embed
    }

/*TESTING
original = '''
priority 1000
snippet 'sympy(.*)sympy' "sympy" wr
`!p
from sympy import *
x, y, z, t = symbols('x y z t')
k, m, n = symbols('k m n', integer=True)
f, g, h = symbols('f g h', cls=Function)
init_printing()
snip.rv = eval('latex(' + match.group(1).replace('\\', '').replace('^', '**').replace('{', '(').replace('}', ')') + ')')
`
endsnippet
'''
snippet = extract-snippet original
generated = generate-snippet snippet

sep = -> console.log '-' * 46
console.log original
sep()
console.log snippet
sep()
console.log generated

generate-tabstop(
    position: 2
    default-value: null
    substitution: ['this:\\/\\/url', 'hey-hey!!!/']
) |> console.log
*/
