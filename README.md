# SS modifier

An Api for converting your surge configuration.

You can simply insert, replace or delete some config in your surge profile. All you need to do is writing a modifier config file and update your managed URL.

- [Intro](#Intro)
- [Modifier format](#Modifier)
- [Example](#Example)

## Intro

SS modifier is written in pure Swift.

Feel free to leave any issues.

## Send Request

**Get** `https://ss.kaelzs.com/surge/convert`

### Parameters

> `urls` (String or [String], required): Your surge modifier urls.
>
> `name` (String, optional, default to `surge.conf`): The response file name.
>
> `preview` (Bool, optional, default to false): if set to true, the response content type will be set to `text/plain`.
>
> `managed` (Bool, optional, default to true): if set to false, the surge config will not managed by url.
>
> `interval` (Bool, optional, default to 3600): the update interval of managed config.
>
> `strict` (Bool, optional, default to false): weather need strict update when managed config outdated.

## Modifier

### Group Modifier

There's two kind of group modifier, `replace` or `modify`, you can declare the type in any surge group, the default type is `replace`.

``` Properties
[General]
#!type replace

[Replica]
#!type modify
```

The replacing modifier will replace the entire group of current profile, while the modifying modifier will just do some modification to the group of current profile.

### Plain line

The plain line is only supported in replacing modifier, you can just write the config as in the surge config. Plain line will be ignored when written in modifying modifier.

``` Properties
[General]
#!type repalce
# > General
http-listen = 0.0.0.0:8888
socks5-listen = 0.0.0.0:8889

external-controller-access = Kaelzs@0.0.0.0:6170

internet-test-url = http://www.qualcomm.cn/generate_204
proxy-test-url = http://www.qualcomm.cn/generate_204
```

### Modifier line

The modifier line declares how to modify the group of current profile. You can declare the modifier line by adding `#!insert` or `#!append` before any plain line, it will insert or append the line to the group of current profile.

``` Properties
[Rule]
#!type modify

#!insert # > Tool
#!insert # >> Zeplin
#!insert DOMAIN-SUFFIX,zeplin.io,Proxy

[Proxy]
#!type modify

#!append My-Custom-SS = snell, example.com, 12345, psk = 1234, obfs = tls
```

### Remote resources

You can add some remote resource to modifier, it will replace the line by the same group of the remote profile.

``` Properties
[URL Rewrite]
#!type replace
#!insert $from('https://raw.githubusercontent.com/rixCloud-Inc/rixCloud_Surge-Data/master/surge3_rules')

# > the modifier will find the same group (URL Rewrite) of the remote resource (or just using the
# >   whole remote resource), and insert them to the start of current group (URL Rewrite). The modifier
# >   will find the same group (URL Rewrite) of the remote resource, and insert them to the start of
# >   current group (URL Rewrite).

[MITM]
#!type replace
$from('https://raw.githubusercontent.com/lhie1/Rules/master/Surge/Surge%203/MitM.conf')
```

### Update modifier

There are three kind of update modifier, `insert`, `append` and `replace`.

``` Properties
[Proxy Group]
#!type replace
Proxy = select, Direct

[Proxy Group]
#!type modify
#!update-insert-1 Proxy = HK

# > the modifier will insert the `HK` to the second property of the Proxy, and will
# > output to Proxy = select, HK, Direct
```

> `#!update-insert-0 A = B, C` will insert `B, C` to the first property of `A`.
>
> `#!update-append-0 A = B, C` will append `B, C` to the last property of `A`.
>
> `#!update-replace A = B, C` will replace the original properties of `A` to `A = B, C`.

### Proxy filter

You can use `$group('Name', operator, 'operand')` to filter the keys of the modifier group with specific name. You can use `#!name XXX` to specific the name of the group.

#### Supported operator

> `contains` filter the keys whose name contains the operand.
>
> `matches` filter the keys whose name (regex) match the operand.
>
> `prefix` filter the keys whose name has operand prefix.
>
> `suffix` filter the keys whose name has operand suffix.
>

``` Properties
[Proxy]
#!type modify
#!name ProxyList

#!insert $from('https://proxy.list/from/some/conf/')

[Proxy Group]
#!type modify

#!append Daily = url-test, $group('ProxyList', contains, 'Daily'), url = http://www.qualcomm.cn/generate_204, interval = 300, tolerance = 100, timeout = 5
```

## Example

- [basicRules.conf](https://github.com/Kaelzs/SS-Modifier/tree/master/basicRules.conf)
- [modifier.example.conf](https://github.com/Kaelzs/SS-Modifier/tree/master/modifier.example.conf)