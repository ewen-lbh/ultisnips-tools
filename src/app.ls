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
        return flags: null, trigger: null, name: null

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
    for line in source / '\n'
        line .= trim!
        console.log line
        priority ||= get-priority line
        post-jump ||= get-post-jump line
        { flags, trigger, name } ||= parse-snippet-line line
        context ||= get-context line
    
    content = get-content source
    
    return { priority, post-jump, flags, trigger, name, context, content }

generate-snippet = ({priority, post-jump, flags, trigger, name, context, content}) ->
    prority-string = if priority != null then "prority #priority\n" else ''
    context-string = if context != null then "context #context\n" else ''
    post-jump-string = if post-jump != null then "post_jump #post-jump\n" else ''
    flags-string = Object.entries(flags)
        .filter(([k, v]) -> v) # Filter by value (is the flag present?)
        .map(([k,v]) -> k) # Map by key (get the flag name, not true or false)
        .join('') # Join into a string ([\w, \r] -> \wr )
    
    (prority-string + context-string + post-jump-string +
    """
    snippet '#trigger' "#name" #flags-string
    #content
    endsnippet
    """).trim()

generate-tabstop = ({ position, default-value, substitution }) ->
    if position == 0
        \$0
    else if default-value
        "${#position:#default-value}"
    else if substitution and substitution.length == 2
        [search, replace] = substitution.map (v) -> v.replace /(?<!\\)\//g '\\/'
        "${#position/#search/#replace/g}"

generate-code-embed = ({language, content}) ->
    switch language
    case \shell then 
        """`
        #content
        `"""
    case \python then 
        """`!p
        #content
        `"""
    case \vimscript then
        """`!v
        #content
        `"""
    default
        null

generate-tabstop-reference = ({ language, position }) ->
    switch language
    case \python then
        "t[#position}]"
    default
        null

generate-content-assignement = ({ language }) ->
    switch language
    case \python then
        'snip.rv = '
    default
        null

generate-trigger-regex-group-reference = ({ language, position }) ->
    switch language
    case \python then
        "match.group(#position)"
    default
        null
    

if typeof window != \undefined
    window <<< {generate-snippet, extract-snippet, generate-tabstop, generate-trigger-regex-group-reference, generate-content-assignement}

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
