#!/usr/bin/perl
package CBRBalance;
use strict;
use POSIX qw(strftime);
use XML::TreePP;
use Data::Dumper;
use DBI;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    bless( $self, $class );
    return $self->_init(@_);
}
sub _init {
    my $self = shift;
    $self->{dbh} = shift;
    my $curr=shift; 
    my $date=shift;
    $self->set_date($date);
    $self->set_curr($curr);
    return $self;
}
#Задает дату в формате MYSQL
sub set_date{#hhhh-mm-dd
    my $self = shift;
    my $date = shift;
    $self->{'_date'}=$date;
    return undef;
}
#Возвращает текущую дату в формате MYSQL
sub get_now_date{#hhhh-mm-dd
    my $self = shift;
    return strftime "%Y-%m-%d", localtime;
}
#Возвращает дату в формате MYSQL, по умолчанию текущая дата
sub get_date{#hhhh-mm-dd
    my $self = shift;
    return !($self->{'_date'}) ? $self->get_now_date() : $self->{'_date'};
}
#Возвращает время запроса
sub get_time{
    my $self = shift;
    my $time=strftime "%H:%M:%S", localtime;
    return $time;
}
#Задает валюту
sub set_curr{
    my $self = shift;
    my $curr = shift;
    $self->{'_curr'} = $curr;
    return undef;
}
#Возвращает валюту, по умолчанию 'USD'
sub get_curr {
    my $self = shift;
    return !($self->{'_curr'}) ? 'USD' : $self->{'_curr'};
}
#Конвертирует и возвращает дату для работы с ЦБР
sub get_date_cbr_fmt{
    my $self=shift;
    my ($date)=@_;
    $date ||= $self->get_date();
    $date =~ /^(\d{4})-(\d{2})-(\d{2})/;
    $date =$3.'/'.$2.'/'.$1;
    return $date;
}
#Возвращает курс валюты от ЦБР
sub get_cbr_rate{#Принимает валюту и дату
    my $self=shift;
    my $rate=undef;
    my ($curr, $date)= @_;
    my $cbr_url='http://www.cbr.ru/scripts/XML_daily.asp?date_req='.$date;
    my $tpp = XML::TreePP->new();
    my $tree = $tpp->parsehttp( GET => $cbr_url );
    my @arr;
    foreach(@{$tree->{'ValCurs'}->{'Valute'}}){
        if($_->{CharCode} eq $curr){
            $rate=$_->{Value};
            $rate =~ /^(\d+),(\d+)/;
            $rate =$1.'.'.$2;
        }
    }
        return $rate;
        # warn Dumper $rate;
}
#Сохраняет курс валюты на дату от ЦБР
sub set_cbr_rate_date{
    my $self=shift;
    my $rate=shift;
    $self->{'_rate'}=$rate;
    return undef;
}
#Возвращает курс валюты на дату от ЦБР
sub get_cbr_rate_date{
    my $self=shift;
    return $self->{'_rate'};
}
#Сохраняет курс валюты в базу
sub save{ #($curr, $date, $rate) 
    my $self=shift;
    my $curr=$self->get_curr();
    my $date=$self->get_date();
     # return $date;
    my $rate=$self->get_cbr_rate($curr, $self->get_date_cbr_fmt());
    my $time=$self->get_time();
    $self->{dbh}->do('INSERT INTO currencies VALUES (?,?,?,?)', undef, $curr, $date, $time,$rate);
    return undef;
}
#Возвращает курс валюты из базы
sub get_db_rate{#($curr, $date) 
    my @rate=undef;
    my $self=shift;
    my $curr=$self->get_curr();
    my $date=$self->get_date();
    my @ary_ref = $self->{dbh}->selectall_array('SELECT rate FROM currencies WHERE curr=? AND rdate=? ORDER BY time ', undef, $curr, $date);
    return [map{ @$_ }@ary_ref];
}
#Формирование шаблона
sub get_template{#принимает путь к шаблону
    my $self = shift;
    my $template = shift;
    my $date=$self -> get_date();
    # return $date;
    my $cbr_date=$self -> get_date_cbr_fmt($date);#Получение даты для запроса на дату
    my $cbr_date_now=$self -> get_date_cbr_fmt($self -> get_now_date());#Получение даты для запроса на сегодня
    my $curr =$self -> get_curr();#Передаю значение валюты в переменную

    my @rates;#Инициализирую пустой массив для курсов
    my @arr=$self->get_db_rate();#Запрос к базе за курсом на дату
    foreach my $i(@{ $arr[0] }){
        push @rates, $i;#Полученные из базы данные помещаю в массив
    }

    my $rates=@rates;#кол-во элементов в массиве
    $rates ? @rates : ( $self->save() , push @rates, ($self -> get_cbr_rate($curr, $cbr_date)));#если элементов 0, значет в базе ничего нет, делаю запрос к ЦБР и сохраняю в базу
    my $rate_now=$self -> get_cbr_rate($curr, $cbr_date_now); #Получение курса на сегодня

    my $file = $template;#Указываю файл с шаблоном
    my $vars = {#переменные которые будут в шаблоне
        curr => $self->get_curr(),
        rate_now => $rate_now,
        date_now => $self->get_now_date(),
        date => $self->get_date(),
        rates => \@rates,
    };

    my $template = Template->new();#новый объект Template
        $template->process($file, $vars)#Передаем методу шаблон и переменные
            || die "Template process failed: ", $template->error();#В случае ошибки- текст ошибки
    return undef;
}
1;