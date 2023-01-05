# kenk-vk-enricher
## Russian
ВКонтакте не позволяет полноценно выгрузить из себя пользовательские данные. Запросив выгрузку на странице https://vk.com/data_protection, через некоторое время пользователь получает относительно небольшой zip архив, внутри которого расположен набор слинкованных html страниц без медиафайлов. Сами медиаматериалы (изображения и видео) в архив не попадают — указаны только либо ссылки на исходные объекты в ВК, либо фото (или превью видео), которые подгружаются с серверов ВК в интернете. 

Этот скрипт умеет парсить скачанный вами предварительно дамп, загружать из интернета оригиналы файлов, сохранять их в папке дампа и менять HTML код файлов выгрузки так, чтобы данные были доступны локально (и независимо от воли и работы соцсети)

### Использование
* скачайте скрипт и разверните его в папку
* положите содержимое выгрузки профиля в папки "Archive" и "Fixed" 
* запустите скрипт
* по окончании работы исправленный дамп будет расположен в "Fixed" 

Исправленные данные содержат всё содержимое оригинального дампа, с изменениями:
* все картинки в разделе "Сообщения" выкачиваются и распологаются локально, открываются из html
* все картинки в разделе "Фотографии" выкачиваются и распологаются локально, открываются из html
* все картинки в разделе "Фотографии" лежат в подкаталоге Fixed\photos-src, сгруппированые по папкам с именами оригинальных альбомов в веб интерфейсе, описания фотографий (если были даны) сохраняются рядом в файлы *.txt

Лог работы записывается в файлы в каталоге Logs

## English 
You can get dump of your vk.com profile via https://vk.com/data_protection, but archive will not contain media - instead of this, html files in archive using links to original media at VK's server

This script parses dump, downloads original files to dump's folder and makes data avaliable locally without connection to internet 

### Usage
* download script and unzip it
* place copies of original dump data to "Archive" and "Fixed" folders
* if you are using non-russian language in profile, set correct value for $FOTOS_DIV_DESCRIPTION variable
* run script
* get modified dump in "Fixed" folder after end of script

Fixed folder contains all original data, but
* all fotos at dialogs downloaded and stored locally, html now links to it
* all fotos in fotoalbums downloaded and stored locally, html now links to it
* fotos for fotoalbums stored in subfolder Fixed\photos-src, placed at folders named as original albums in web interface, descriptions of fotos (if any) are saved in nearby *.txt files

