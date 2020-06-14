c = console.log

get-priority = (line) ->
    pattern = /^priority (\d+)$/
    priority = line.replace pattern, \$1 |> Number
    if priority |> isNaN then null else priority

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
    { groups } = pattern.exec(line) or { groups: null }

    if not groups?
        return null

    return
        flags: groups.flags |> flags-string-to-object
        trigger: groups.trigger or groups.triggerQuoted
        name: groups.name

flags-string-to-object = (flags-string) ->
    flags-object = {}
    for flag in <[b i w r t s m e A]>
        flags-object[flag] = flag in flags-string
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

    return content-lines * '\n'
    
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
        if not seen.snippet-line and parse-snippet-line(line)?
            # other directives must be set before the snippet line so mark everything else as seen too
            seen.post-jump = seen.priority = seen.context = seen.snippet-line = true
            { trigger, name, flags } = parse-snippet-line line
        else if not seen.priority and get-priority(line)?
            priority = get-priority line
            seen.priority = true
        else if not seen.context and get-context(line)?
            context = get-context line
            seen.context = true
        else if not seen.post-jump and get-post-jump(line)?
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
    
    flags-string = (
        # For each flag, filter by value (is the flag present?)
        for own let k, v of flags when v 
        # Map by key (get the flag character)
            k
    ) * '' # Join into a string (['a', 'b'] becomes 'ab')
    
    (priority-string + context-string + post-jump-string +
    """
    snippet '#trigger' "#name" #flags-string
    #content
    endsnippet
    """).trim!

generate-tabstop = ({ position, default-value, substitution }) ->
    if default-value
        "${#position:#default-value} "
    else if substitution and substitution.length == 2
        [search, replace] = substitution.map (v) -> v.replace /(?<!\\)\//g '\\/'
        "${#position/#search/#replace/g} "
    else if position
        "$#position "

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
        "t[#position] "
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
        "match.group(#position) "
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
