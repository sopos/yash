### YASH
An implementation of YAml parser in pure baSH.

At this point it is very simple and naive. There is no escapes handling.
It was create to be able to pasre almost flat structure eventhough it is able
to handle deep structures as well.

### Usage

```
. ./ya.sh
yaml_input="- value1
- value2"
unset yaml; declate -A yaml
yash_parse yaml "$yaml_input"

echo ${yaml[0]}
```

```
. ./ya.sh
yaml_input="- key1: value1
- key2:
  - value2
  - value3"
unset yaml; declate -A yaml
yash_parse yaml "$yaml_input"

echo ${yaml[1.key2.0]}
```
