
# MedOrg Installer

Автоматический установщик медицинской программы MedOrg.

## Быстрая установка

bash
```
curl -sSL https://raw.githubusercontent.com/kubinets/medorg-installer/main/install.sh | sudo bash
```

## Особенности

- Анимированный интерфейс с эффектом печатающей машинки
- Автоматическая установка всех зависимостей
- Настройка Wine с необходимыми компонентами
- Копирование программы с сетевой шары
- Исправление проблем с midas.dll (регистр букв)
- Создание ярлыков на рабочем столе

## Все модули

text

```
Admin           BolList         DayStac         Dispanser
DopDisp         Econ            EconRA          EconRost
Fluoro          Kiosk           KTFOMSAgentDisp KTFOMSAgentGosp
KTFOMSAgentPolis KTFOMSAgentReg KubNaprAgent    MainSestStac
MedOsm          MISAgent        OtdelStac       Pokoy
RegPeople       RegPol          San             SanDoc
SpravkaOMS      StatPol         StatStac        StatYear
Tablo           Talon           Vedom           VistaAgent
WrachPol
```

## Обязательные модули (устанавливаются всегда)

- Lib
- LibDRV
- LibLinux

## Использование

1. Запустите установщик с правами root
2. Введите имя пользователя
3. Выберите модули для установки
4. После установки войдите под указанным пользователем
5. Запускайте программы из папки "Медицинские программы" на рабочем столе

## Исправление проблем

Если возникают проблемы с midas.dll:

bash

```
~/fix_midas_case.sh
```

## Требования

- RedOS 7+ / RHEL 8+ / CentOS 8+
- Права root (sudo)
- Доступ к сетевой шаре 

## Структура проекта

- `install.sh` \- главный скрипт
- `modules/` \- модули установки
	- `01-dependencies.sh` \- зависимости
	- `02-wine-setup.sh` \- настройка Wine
	- `03-copy-files.sh` \- копирование файлов
	- `04-fix-midas.sh` \- исправление midas.dll
	- `05-create-shortcuts.sh` \- создание ярлыков

## Лицензия

MIT License