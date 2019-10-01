#!/usr/bin/perl
use strict;
use lib qw(./);
use CBRBalance;
use Data::Dumper;
use DBI;
use Template;

my $user = "root";
my $password = "";
my $database='currdesc';
my $hostname='localhost';
my $port=3306;
my $dsn = "DBI:mysql:database=$database;host=$hostname;port=$port";
my $dbh = DBI->connect($dsn, $user, $password);

my $curr = undef;
my $date = '2015-09-10';

my $cl = CBRBalance->new($dbh,$curr,$date);

$cl -> set_curr();#Задаю валюту
$cl -> set_date($date);#Задаю дату
$curr =$cl -> get_curr();#Передаю значение валюты в переменную

# my $cbr_date=$cl -> get_date_cbr_fmt($cl -> get_date());#Получение даты для запроса на дату
# my $cbr_date_now=$cl -> get_date_cbr_fmt($cl -> get_now_date());#Получение даты для запроса на сегодня

# my @rates;#Инициализирую пустой массив для курсов
# my @arr=$cl->get_db_rate();#Запрос к базе за курсом на дату
# foreach my $i(@{ $arr[0] }){
#     push @rates, $i;#Полученные из базы данные помещаю в массив
# }
# my $rates=@rates;#кол-во элементов в массиве
# $rates ? @rates : ( $cl->save() , push @rates, ($cl -> get_cbr_rate($curr, $cbr_date)));#если элементов 0, значет в базе ничего нет, делаю запрос к ЦБР и сохраняю в базу
# my $rate_now=$cl -> get_cbr_rate($curr, $cbr_date_now); #Получение курса на сегодня

# my $file = 'page.txt';#Указываю файл с шаблоном
# my $vars = {#переменные которые будут в шаблоне
#     curr => $cl->get_curr(),
#     rate_now => $rate_now,
#     date_now => $cl->get_now_date(),
#     date => $cl->get_date(),
#     rates => \@rates,
# };
# my $template = Template->new();#новый объект Template
#     $template->process($file, $vars)#Передаем методу шаблон и переменные
#         || die "Template process failed: ", $template->error();#В случае ошибки- текст ошибки
print($cl -> get_template('page.txt'));
$dbh->disconnect;