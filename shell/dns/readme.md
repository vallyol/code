# Тестирование DNS при помощи bash-скриптов

## dns-test.sh - тестирование ДНС серверов

Скрипт проверяет ответ указанного домена через различные публичные ДНС серверы (используется dig, поэтому он должен быть установлен в системе). Проверить, установлен ли dig, можно вызвав его в терминале на Линукс системах или в termux на Андроид. Если dig отсутствует, система предложит установить его, показав необходимую команду.

Результаты выводятся в виде таблицы, в которой первой стройкой отображается ответ домена через ваш текущий ДНС сервер: провайдера или оператора сотовой связи. Если проверка производится с устройства, на которой интернет раздается с мобильного телефона, скрипт в качестве текущего ДНС сервера укажет адрес телефона (например, 192.168.43.1).

### Пример вывода в терминале

```
Тестируем время запроса к ya.ru

Сервис               Сервер          Статус               Query time
-------------------- --------------- -------------------- ----------
Current DNS          192.168.43.1    OK                   4 msec

AdGuard DNS          94.140.14.14    OK                   96 msec
Comodo Secure        8.26.56.26      OK                   76 msec
Yandex DNS           77.88.8.8       OK                   36 msec
Control D            76.76.2.4       OK                   80 msec
Alibaba              223.5.5.5       OK                   32 msec
Neustar Ultra        156.154.70.5    OK                   72 msec
CleanBrowsing        185.228.168.9   OK                   84 msec
OpenDNS              208.67.222.222  OK                   84 msec
Google DNS           8.8.8.8         OK                   48 msec
Quad9                9.9.9.9         OK                   200 msec
Mullvad              194.242.2.2     OK                   96 msec
Cloudflare DNS       1.1.1.1         OK                   44 msec

```

### Запуск скрипта

Для запуска необходимо после названия скрипта указать тестируемый домен, например youtube.com или ya.ru. Если не указать домен, скрипт закончит работу, сообщив, что доменное имя не указано.

```
$ ./dns-test.sh ya.ru
```

### Список публичных ДНС серверов

Список задан прямо в теле скрипта. Это ассоциативный массив вида `имя = адрес`. Всегда можно изменить список ДНС серверов, удалив ненужные или добавив желаемые. На данный момент для тестирования используются

```
servers=(
  ["Google DNS"]="8.8.8.8"
  ["Cloudflare DNS"]="1.1.1.1"
  ["Quad9"]="9.9.9.9"
  ["OpenDNS"]="208.67.222.222"
  ["AdGuard DNS"]="94.140.14.14"
  ["Comodo Secure"]="8.26.56.26"
  ["CleanBrowsing"]="185.228.168.9"
  ["Control D"]="76.76.2.4"
  ["Neustar Ultra"]="156.154.70.5"
  ["Yandex DNS"]="77.88.8.8"
  ["Alibaba"]="223.5.5.5"
  ["Mullvad"]="194.242.2.2"
)
```

### Для чего нужен?

Кроме показа в сравнении времени ответа выбранного домена через различные публичные ДНС сервера (что позволит, при желании, использовать самый быстрый ДНС сервер в сетевых настройках своего устролйства) скрипт создавался для проверки блокировки ДНС серверов провайдером. 

В мобильной сети при проблемах с мобильным интернетом при помощи скрипта легко определить, включил ли оператор сотовой связи белые списки или нет. К примеру, при белых списках на Билайн доступны всего два ДНС сервера: сервер самого Билайн и публичный ДНС гугла (8.8.8.8).

Также в Билайн я последнее время наблюдаю очень странную работу их сети, когда запросы к любому домену через ДНС сервер Билайн отвечают за время порядка 400-800мс. Соответственно, все сервера из списка для тестирования показывают время ответа еще большее...

### Как это выглядит при белых списках

```
$ ./dns-test.sh youtube.com

Тестируем время запроса к youtube.com

Сервис               Сервер          Статус               Query time
-------------------- --------------- -------------------- ----------
Current DNS          192.168.43.1    OK                   24 msec

AdGuard DNS          94.140.14.14    ERROR                N/A
Comodo Secure        8.26.56.26      ERROR                N/A
Yandex DNS           77.88.8.8       OK                   32 msec
Control D            76.76.2.4       ERROR                N/A
Alibaba              223.5.5.5       ERROR                N/A
Neustar Ultra        156.154.70.5    ERROR                N/A
CleanBrowsing        185.228.168.9   ERROR                N/A
OpenDNS              208.67.222.222  ERROR                N/A
Google DNS           8.8.8.8         OK                   48 msec
Quad9                9.9.9.9         ERROR                N/A
Mullvad              194.242.2.2     ERROR                N/A
Cloudflare DNS       1.1.1.1         ERROR                N/A
```

При задействовании белых списков оператор мобильной сети блокирует практически все публичные ДНС сервере, оставляя для запросов пользователей только свой собственный и яндекс днс. В билайн отвечает также публичный ДНС гугл...

## Тестирование doh

doh (DNS через HTTPS) - шифрует ДНС запросы при помощи https, что позволяет скрыть ваши запросы от провайдера и третьих лиц (MITM). При этом запросы становятся неотличимы от обычного https трафика за счет создания шифрованного соединения с преобразователем doh. Распознаватель doh расшифровывает запрос, ищет нужный домен, шифрует ответ и отправляет его обратно через защищенное соединение. Браузер, зная к какому преобразователю отправлялся запрос и каким tls он шифровался, имеет возможность расшифровать полученный ответ.

Тестирование проводится при помощи curl, который может создать запрос, аналогичный браузерному, и вывести результат в нужном нам формате. Например

```
$ curl -s -H "accept: application/dns-json" "https://cloudflare-dns.com/dns-query?name=youtube.com&type=A"

```

Результат будет представлен как json объект:

```
{
  "Status":0,
  "TC":false,
  "RD":true,
  "RA":true,
  "AD":false,
  "CD":false,
  "Question":[{"name":"youtube.com","type":1}],
  "Answer":[
    {"name":"youtube.com","type":1,"TTL":168,"data":"209.85.233.93"},
    {"name":"youtube.com","type":1,"TTL":168,"data":"209.85.233.136"},
    {"name":"youtube.com","type":1,"TTL":168,"data":"209.85.233.91"},
    {"name":"youtube.com","type":1,"TTL":168,"data":"209.85.233.190"}
  ]
}
```

Расшифровка флагов:
- status: 0 NOERROR
- TC (Truncated): false ответ не был обрезан
- RD (Recursion Desired): true рекурсивный поиск, если ответ не будет получен
- RA (Recursion Available): true поддержка рекурсивных запросов на сервере имеется
- AD (Authentic Data): false проверка DNSSEC
- CD (Checking Disabled): false включена или нет проверка DNSSEC
- Question запрос, здесь запрашивается домен youtube.com и тип записи A
- Answer секция ответа, здесь для имени youtube выводится подтверждение, что получен IP v4 адрес (type":1) с времением кэширования 168мс (время, в течении которого не будут отправляться повторные запросы)

### doh-test.sh - простой тест doh

Скрипт проверяет работоспособность конкретного doh ретранслятора. Если ответ был получен, и его статус равен 0, выводится сообщение об успешной проверке, включающей IP адреса тестируемого домена.

Так как для работы скрипта требуется curl, вначале прописана проверка с мини-инструкцией, как его установить в Линукс и MacOS.

Для запуска после названия мкрипта необходимо указать название любого домена. Если необходимло проверить другой doh ретранслятор, в скрипте можно изменить переменную `DOH_URL` с cloudflare на любой проверяемый.

#### Пример вывода в терминале

```
$ ./doh-test.sh youtube.com
curl найден. Продолжаем...
Анализ сетевого окружения...
Ваш текущий DNS-сервер: 192.168.43.1 (может быть IP-адресом вашего телефона)
Тестируем DoH-запрос через https://cloudflare-dns.com/dns-query...
Успех! DoH работает корректно.
Ответ от сервера:
"data":"173.194.73.91"
"data":"173.194.73.93"
"data":"173.194.73.190"
```

#### Почему адреса в ответах отличаются

Видно, что IP адреса домена youtube.com в выводе curl и в ответе скрипта отличаются. Это - не подмена адреса. Связано с тем, что запрос, сделанный курлом проходит через dns сервера местного провайдера, а скрипт напрямую обращается к doh ретранслятору `cloudflare-dns.com/dns-query`. Так как youtube - это ресурс, использующий GGC, при запуске curl нам отвечают сервера, размещенные максимально близко от нашего физического расположения.

Проверим ответ для любого не трансграничного домена:

```
$ curl -s -H "accept: application/dns-json" "https://cloudflare-dns.com/dns-query?name=web.dev&type=A"
{
  "Status":0,
  "TC":false,
  "RD":true,
  "RA":true,
  "AD":false,
  "CD":false,
  "Question":[{"name":"web.dev","type":1}],
  "Answer":[
    {"name":"web.dev","type":1,"TTL":300,"data":"216.239.32.27"}
  ]
}
```

```
$ ./doh-test.sh web.dev
curl найден. Продолжаем...
Анализ сетевого окружения...
Ваш текущий DNS-сервер: 192.168.43.1 (может быть IP-адресом вашего телефона)
Тестируем DoH-запрос через https://cloudflare-dns.com/dns-query...
Успех! DoH работает корректно.
Ответ от сервера:
"data":"216.239.32.27"
```

IP адрес запрашиваемого ресурса тот же самый.

#### А что при белых списках...

Обычный домен через распознавателя doh от cloudflare:

```
$ ./doh-test.sh web.dev
curl найден. Продолжаем...
Анализ сетевого окружения...
Ваш текущий DNS-сервер: 192.168.43.1 (может быть IP-адресом вашего телефона)
Тестируем DoH-запрос через https://cloudflare-dns.com/dns-query...
Ошибка: не удалось выполнить DoH-запрос. Проверьте подключение к интернету.
```

Тестирование doh с использованием dns.google и домена ya.ru в сети билайн дает такой же результат.

```
$ ./doh-test.sh ya.ru
curl найден. Продолжаем...
Анализ сетевого окружения...
Ваш текущий DNS-сервер: 192.168.43.1 (может быть IP-адресом вашего телефона)
Тестируем DoH-запрос через https://dns.google/dns-query...
Ошибка: не удалось выполнить DoH-запрос. Проверьте подключение к интернету.
```

Провайдер полностью блокирует doh при включении белых списков

### doh-test2.sh

Простота тестирования первым doh-тестом радует: при помощи curl мы обращаемся к любому домену, используя выбранный публичный doh ретранслятор. Но, если нам необходимо проверить работоспособность нескольких днс серверов, придется каждый раз открывать сам скрипт и редактировать переменную `DOH_URL`. Поэтому - второй тестировщик работоспособности doh...

#### Запуск скрипта

В скрипт добавлена возможность запускать его, используя некоторые аргументы. Например, теперь запуск должен происходить не просто как `./script_name.sh domen`, а с указанием аргумента `-d` перед доменом.

```
$ ./doh-test2.sh -d ya.ru
```

#### Список аргументов с пояснениями

```
Options:
  -d DOMAIN     Домен для проверки (обязательно)
  -t TYPE       Тип записи: A|AAAA|MX|TXT|NS|CNAME (по умолчанию: A)
  -p PROVIDER   Провайдер: cloudflare|google|quad9|adguard|adguard_family|nextdns|opendns|yandex|mullvad|cleanbrowsing|libredns|snopyta|all
                (по умолчанию: all)
  -g GROUP      Тег для фильтрации: privacy|filtering|family|security|standard
  -v            Подробный вывод
  -h            Справка
```

Если аргумент не указан, используется значение по умолчанию. Указание "-d" является обязательным. При задействовании подробного вывода "-v" будет показан вывод curl с разметкой и кодом ошибки, если такая имеется.

#### Пример вывода в терминале

Для случаев, когда указывается один аргумент "-d":

```
$ ./doh-test2.sh -d ya.ru
Provider         Status     HTTP   Time     Tags                     Result                                                                
--------         ------     ----   ----     ----                     ------                                                                
cloudflare       OK 200    375ms    privacy,security,stan... ya.ru 420 1 77.88.44.242;ya.ru 420 1 77.88.55.242 ya.ru 420 1 5.255...
google           WARN 400    1518ms   standard,security        HTTP error                                                            
quad9            WARN 400    500ms    privacy,security         HTTP error                                                            
nextdns          OK 200    351ms    privacy,filtering,family ya.ru. 79 1 77.88.55.242;ya.ru. 79 1 77.88.44.242 ya.ru. 79 1 5.255...
opendns          WARN 400    440ms    security,family          HTTP error                                                            
cleanbrowsing    WARN 400    475ms    family,filtering         HTTP error                                                            
mullvad          WARN 400    395ms    privacy,standard         HTTP error                                                            
adguard          WARN 400    344ms    privacy,filtering        HTTP error                                                            
adguard_family   WARN 400    494ms    family,filtering         HTTP error
```

С аргументом "-g" (некоторые днс сервера предлагают различные адреса для фильтрации по типа "безопасность"/"family"/приватность):

```
$ ./doh-test2.sh -d ya.ru -g security
Provider         Status     HTTP   Time     Tags                     Result                                                                
--------         ------     ----   ----     ----                     ------                                                                
cloudflare       OK 200    236ms    privacy,security,stan... ya.ru 515 1 5.255.255.242;ya.ru 515 1 77.88.55.242 ya.ru 515 1 77.8...
google           WARN 400    1328ms   standard,security        HTTP error                                                            
quad9            WARN 400    372ms    privacy,security         HTTP error                                                            
opendns          WARN 400    368ms    security,family          HTTP error
```

Полезность аргумента пока под вопросом... Потому, что в данный момент в выводе просто показываются те ретрансляторы, у которых такой функционал заложен. Без, собственно, тестирования по принадлежности к тегу.

#### Описание статуса

Их три: 
- OK, что означает "всё хорошо"
- WARN, "предупреждение", что не обязательно "плохо"... для части провайдеров это скорее несоответствие их формата запроса нашему `application/dns-json`
- FAIL, это конкретная ошибка, провайдер недоступен/заблокирован

#### А что при белых списках...

```
$ ./doh-test2.sh -d ya.ru
Provider         Status     HTTP   Time     Tags                     Result                                                                
--------         ------     ----   ----     ----                     ------                                                                
curl: (28) Connection timed out after 5000 milliseconds
cloudflare       FAIL 000    0ms      privacy,security,stan... curl error                                                            
curl: (28) Connection timed out after 5000 milliseconds
google           FAIL 000    0ms      standard,security        curl error                                                            
curl: (28) Connection timed out after 5000 milliseconds
quad9            FAIL 000    0ms      privacy,security         curl error                                                            
curl: (28) Connection timed out after 5000 milliseconds
nextdns          FAIL 000    0ms      privacy,filtering,family curl error                                                            
curl: (28) Connection timed out after 5000 milliseconds
opendns          FAIL 000    0ms      security,family          curl error                                                            
curl: (28) Connection timed out after 5000 milliseconds
cleanbrowsing    FAIL 000    0ms      family,filtering         curl error                                                            
curl: (28) Connection timed out after 5002 milliseconds
mullvad          FAIL 000    0ms      privacy,standard         curl error                                                            
curl: (28) Connection timed out after 5001 milliseconds
adguard          FAIL 000    0ms      privacy,filtering        curl error                                                            
curl: (28) Connection timed out after 5002 milliseconds
adguard_family   FAIL 000    0ms      family,filtering         curl error
```

Всё лежит... Curl не дождался ответа в течении 5 секунд.

#### Мини выводы из работы скрипта

Особенной ценности скрипт не имеет. Единственное - это диагностика того, что осталось еще рабочим... в условиях, когда доступных общепризнанных инструментов безопасности становится всё меньше.

Последнее...  
Интересно наблюдать работу сети "в динамике", когда можно сравнить сохраненный результат работы сегодня и два дня назад:

```
$ ./doh-test2.sh -d ya.ru
Provider         Status     HTTP   Time     Tags                     Result                                                                
--------         ------     ----   ----     ----                     ------                                                                
cloudflare       OK 200    271ms    privacy,security,stan... ya.ru 265 1 77.88.44.242;ya.ru 265 1 77.88.55.242 ya.ru 265 1 5.255...
google           WARN 400    1205ms   standard,security        HTTP error                                                            
quad9            WARN 400    305ms    privacy,security         HTTP error                                                            
nextdns          OK 200    504ms    privacy,filtering,family ya.ru. 271 1 5.255.255.242;ya.ru. 271 1 77.88.44.242 ya.ru. 271 1 7...
opendns          WARN 400    553ms    security,family          HTTP error                                                            
cleanbrowsing    WARN 400    373ms    family,filtering         HTTP error                                                            
curl: (28) Connection timed out after 5002 milliseconds
mullvad          FAIL 000    0ms      privacy,standard         curl error                                                            
curl: (28) Connection timed out after 5001 milliseconds
adguard          FAIL 000    0ms      privacy,filtering        curl error                                                            
curl: (28) Connection timed out after 5002 milliseconds
adguard_family   FAIL 000    0ms      family,filtering         curl error
```

Adguard и Mullvad уже недоступны...

#### Правка

Я убрал вывод статуса в цвете, который "ломал" вывод результатов тестирования в табличном виде (сдвиг влево, начиная со столбца http). Теперь результат выглядит так:

```
$ ./doh-test2.sh -d ya.ru
Provider         Status   HTTP     Time       Tags                     Result                                                                 
--------         ------   ----     ----       ----                     ------                                                                 
cloudflare       OK       200      445ms      privacy,security,stan... ya.ru 457 1 5.255.255.242;ya.ru 457 1 77.88.44.242 ya.ru 457 1 77.8... 
google           WARN     400      1267ms     standard,security        HTTP error                                                             
quad9            WARN     400      279ms      privacy,security         HTTP error                                                             
nextdns          OK       200      323ms      privacy,filtering,family ya.ru. 113 1 77.88.44.242;ya.ru. 113 1 77.88.55.242 ya.ru. 113 1 5.... 
opendns          WARN     400      255ms      security,family          HTTP error                                                             
cleanbrowsing    WARN     400      409ms      family,filtering         HTTP error                                                             
curl: (28) Connection timed out after 5002 milliseconds
mullvad          FAIL     000      0ms        privacy,standard         curl error                                                             
curl: (28) Connection timed out after 5001 milliseconds
adguard          FAIL     000      0ms        privacy,filtering        curl error                                                             
curl: (28) Connection timed out after 5002 milliseconds
adguard_family   FAIL     000      0ms        family,filtering         curl error
```

Расшифровка `curl error`, если присутствует, выводится под строкой тестируемого провайдера