#/bin/bash
watch -n 1 'sensors | grep "Core" | awk "{ print \$1, \$2, \$3 }"'