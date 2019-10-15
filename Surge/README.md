# Surge modifier

configuration modifer for Surge.

# Api

- [conveter](#conveter)
- [filter](#filter)

## conveter

**Get** `https://ss.kaelzs.com/surge/converter`

### Parameters

> `url` (String required): Your surge profile url.
>
> `baseUrl` (String optional): The rule you want to use. (The proxy group will be replaced by proxy in profile provided by url).
>
> `modifierUrl` (String optional): The modifier rule.
>
> `name` (String optional, default to `surge.conf`): The response file name.
>
> `preview` (Bool optional, default to 0): if set to true, the response content type will be set to `text/plain`.
>
> `managed` (Bool optional, default to 1): if set to false, the surge config will not managed by url.

### Modifier file format

#### Base

There are two kind of modification for group, `replace` or `modify`. 

You should declare `replace` explicitly. (`[Group Name] Modification type`).

You can also add `$url('http://url.to.your.conf')` to add the content of the url to the config.

#### Example

``` properties
[General] Replace
# Any replace contents
# The whole contents will replace the original config group
# > General
http-listen = 0.0.0.0:8888
socks5-listen = 0.0.0.0:8889

internet-test-url = http://www.qualcomm.cn/generate_204
proxy-test-url = http://www.qualcomm.cn/generate_204

test-timeout = 5
ipv6 = true
show-error-page-for-reject = true

[Rule]
# Any modify contents
# You can insert some line at the start by insert `+` at the start of the line
+ # Tools
+ # Zeplin
+ DOMAIN-SUFFIX,zeplin.io,Proxy

# You can insert some line at the end by insert `++` at the start of the line
++ # connect all other apple website by proxy.
++ DOMAIN-KEYWORD,apple,Proxy

[URL Rewrite] Replace
$url('https://raw.githubusercontent.com/lhie1/Rules/master/Auto/URL%20Rewrite.conf')
$url('https://raw.githubusercontent.com/lhie1/Rules/master/Auto/URL%20REJECT.conf')
```

#### Some specific group

**Managed**

Managed config properties is set in `Managed` config group.

``` properties
[Managed] Replace
interval = 1800 // optional, set interval to 1800
strict = false // optional, set strict to false
```

**Proxy Group**

`$proxy` stands for all proxy

`$proxy(OPERATOR, 'OPERAND', otherOptions...)` stands for filted proxy

**supported operator**

> - contain | contains: proxy name contains the specific operand.
> - prefix | hasPrefix: proxy name has specific operand at prefix.
> - suffix | hasSuffix: proxy name has specific operand at suffix.
> - match | matches: proxy name match the operand regex.

**supported options**

> - caseinsensitive

``` properties
[Proxy Group] Replace
Manual = select, $proxy
BGP = select, $proxy(contains, 'BGP')

HK-AUTO = url-test, $proxy(contains, 'HK'), url = http://www.qualcomm.cn/generate_204, interval = 300, tolerance = 100, timeout = 5
US-MANUAL = select, $proxy(hasSuffix, 'US', caseInsensitive)
```

## filter

**Get** `https://ss.kaelzs.com/surge/filter`

### Parameters

> `url` (String required): Your surge proxy list url.
>
> `type` (String required): Matching type as the **supported operator** below
>
> `operand` (String required): Filter the proxy name by this `oprand`.
>
> `caseInsensitive` (String optional, default to false): wether to judge the operand case insensitively.

### Example url

> https://ss.kaelzs.com/surge/filter?url=https%3A%2F%2Ftest.com%2Fsubscribe%2Fasdasdasd&type=contains&operand=%E9%A6%99%E6%B8%AF

