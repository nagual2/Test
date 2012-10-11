#!/usr/bin/env perl
#
# Title         : test_defrag 0.02
# Date          : October 11, 2012
# Author        : powered by actica
# Web		: https://github.com/nagual2/Test
# Blog		: http://actika.livejournal.com/
# Tested on     : FreeBSD 9.1-PRERELEASE
# Tested on     : perl 5, version 14, subversion 2 (v5.14.2) built for amd64-freebsd-thread-multi
#
# План такой: осуществляем операции записи и чтения на тестируемый диск от 0% заполненности файлами 
# до 100% и вычисляем средние скорости чтения и записи. Как только скорости чтения и записи перестануть 
# падать, считаем фрагментацию максимальной а скорости результирующими для данной фс.
#
# ^ N (Колличество потоков)
# |
# |========== = ------------ ============== --------------- == ---------------
# |----------- ======== ------------------ ---- -------------- ===============
# |================= ----- ================ =================== --------------
# |============ === ------------ == = ============ = ----------- ========== ==
# |================== ==== -- ------------ ------------------------ ----- ----
# |____________________________________________________________________________> T (вермя)
#
# Где --- это чтение, а === это запись.
#
use forks;
use strict;
use warnings;
use v5.14;
use Data::Dumper;
use Time::HiRes qw(gettimeofday tv_interval usleep);
use threads;
use Thread::Queue::Any;
use IO::AIO;
use IO::All;
my $file="/tmp/fs_test01";	# Имя файла для тестирования.
my $fh;				# Дескриптор файла тестирования.
my $data="/dev/random"; # $data="/dev/zero"; # Вариант с zero тест на SendForce2.
my $contents=""; 	# Переменная в которой будет храниться сгенеренные данные.
my $length_data=1024*1024; 	# Длина данных
my $real_length_data;		# То же.
my $taskreq=Thread::Queue::Any->new;
my $answerreq=Thread::Queue::Any->new;
my @threads;
my $all; 		# Здесь будут результаты.
my $max_threads=1; 	# Колличество обработчиков.
my $max_task=10;	# Максимальное колличество заданий.
my $all_space=1024*1024*1024*20; # Размер свободного места под тесты (должно измеряться).
my $logfile="./test_defrag.log";
my $DEBUG=1;
"[$$]: test_defrag.pl Start\n" > io($logfile) if $DEBUG;
#-----------------------------------------------------------------------------
aio_open $data, IO::AIO::O_RDONLY, 0, sub {
    my $fh = shift or die "error while opening: $!";
    aio_read $fh, 0, $length_data, $contents, 0, sub {
	$_[0] == $length_data or die "short read: $!";
 	close $fh;
 	$real_length_data=length($contents);
	print "Буфер создан, размер: ".$real_length_data."\n";
	"[$$]: Буфер создан, размер: ".$real_length_data."\n" >> io($logfile) if $DEBUG;
    };
};
# Ждем завершения.
IO::AIO::flush;
if ($real_length_data<$length_data) {
    print "Мало памяти для тестирования.\n";
    "[$$]: Мало памяти для тестирования.\n" >> io($logfile) if $DEBUG;
    exit 0;
}
#-----------------------------------------------------------------------------
# Контроллёр.
sub thread_boss { 
    print "Старт контролёра.\n";
    "[$$]: Старт контролёра.\n" >> io($logfile) if $DEBUG;
    my $self = threads->self(); 
    my $tid = $self->tid();
    my $task=0; 	# Номер задания.
    my $type;		# Тип задания чтение или запись.
    my $offset;		# Смещение от начала ($content).
    my $length;		# Длина записи.
    my $dataoffset;	# Смещение от начала записываемого файла.
#    my $time_start;	# Время старта операции.
#    my $time_stop;	# Время завершения операции.
    my $exit=0;		# Условие выхода ( 1 - выход). 
    $all->{'file_size'}=0;	# Можно подсчетать.
    $all->{'free_space'}=0;	# Можно подсчитать.
    while (defined( my $job=$answerreq->pending())) {
	next if $exit;
	# Не ждем результаты.
	print "Не ждём результат\n";
	"[$$]: Не ждём результат\n" >> io($logfile) if $DEBUG;
	my ($old_task,$old_type,$old_length,$start_seconds,$start_microseconds,$stop_seconds, $stop_microseconds)=$answerreq->dequeue_dontwait;
	if (defined $old_task) {
	    print "Есть результат: ";
	    print "($old_task,$old_type,$old_length,$start_seconds,$start_microseconds,$stop_seconds, $stop_microseconds)\n";
	    "[$$]: Есть результат: " >> io($logfile) if $DEBUG;
	    "[$$]: ($old_task,$old_type,$old_length,$start_seconds,$start_microseconds,$stop_seconds, $stop_microseconds)\n" >> io($logfile) if $DEBUG;
	    # Обрабатываем результаты.
	    $all->{$old_task}{'type'}=$old_type;
	    $all->{$old_task}{'length'}=$old_length;
	    $all->{$old_task}{'start_seconds'}=$start_seconds;
	    $all->{$old_task}{'start_microseconds'}=$start_microseconds;
	    $all->{$old_task}{'stop_seconds'}=$stop_seconds;
	    $all->{$old_task}{'stop_microseconds'}=$stop_microseconds;
	    $all->{$old_task}{'time_diff'}=tv_interval ([$start_seconds,$start_microseconds],[$stop_seconds,$stop_microseconds]);
	    $all->{$old_task}{'speed'}=$old_length/$all->{$old_task}{'time_diff'};
	    $all->{'file_size'}+=$old_length if $old_type; 	# Если запись добавляем.
	    $all->{'free_space'}=$all_space-$all->{'file_size'};# Свободное место что осталось.
	} else {
	    print "нет результата.\n";
	    "[$$]: нет результата.\n" >> io($logfile) if $DEBUG;
	    if ($job==$max_threads) {
		print "Нет результатов и есть задания для всех обработчиков - пропускаем ход.\n";
		"[$$]: Нет результатов и есть задания для всех обработчиков - пропускаем ход.\n" >> io($logfile) if $DEBUG;
		usleep (10);
		next; # Если нет результатов и есть задания для всех обработчиков - пропускаем ход.
	    } #else { 		# Ставим задания.	    }
	}
	    print "Ставим задания.\n";
	    "[$$]: Ставим задания.\n" >> io($logfile) if $DEBUG;
	    # Ставим задания.
	    $type=int rand 2; 					# 0 - чтение, 1 - запись.
	    if ($type){
		print "Выпало чтение.\n";
		"[$$]: Выпало чтение.\n" >> io($logfile) if $DEBUG;
		next unless $all->{'file_size'}; # Если читать нечего пропускаем ход.
		$offset=int rand $all->{'file_size'};
		$length=int rand ($all->{'file_size'}-$offset);
		# Чтение (не может быть за пределами файла.)				
		$dataoffset=0;					# 0 так как чтение.
	    }else{
	    	print "Выпала запись.\n";
	    	"[$$]: Выпала запись.\n" >> io($logfile) if $DEBUG;
		$offset=int rand $real_length_data; 		# 0 - $real_length_data
		$length=int rand ($real_length_data-$offset); 	# 0 - ($real_length_data-$offset)	    
		# Запись.
	        # Возможны два режима:
		# 1) Диск еще не забит полностью и мы дописываем.
	        # 2) Диск забит полностью и пишем в середину.
		if ($all->{'free_space'}) {
		    # Свободного мета нет - пишем в середину.
		    print "Свободного мета нет - пишем в середину.\n";
		    "[$$]: Свободного мета нет - пишем в середину.\n" >> io($logfile) if $DEBUG;
	    	    $dataoffset=int rand ($all->{'file_size'}); 	# 0 - file_size
	    	    $length=$all->{'file_size'}-$dataoffset if ($length > $all->{'file_size'}-$dataoffset);
	        }else{
	            # Свободное мето есть.
	            print "Свободное мето есть.\n";
	            "[$$]: Свободное мето есть.\n" >> io($logfile) if $DEBUG;
	            # $dataoffset < $all->{'file_size'}+$all->{'free_space'} 
	            # $dataoffset+$length < $all->{'free_space'}
		    $dataoffset=int rand($all->{'file_size'}+$all->{'free_space'});
		    $length=$all->{'file_size'}+$all->{'free_space'} if ($dataoffset+$length > $all->{'file_size'}+$all->{'free_space'});
		}
	    }	
	# Мы сюда не дойдём если у кажого обработчика есть задание.
	print "Сформировано задание: ";
	print "($task,$type,$offset,$length,$dataoffset)\n";
	"[$$]: Сформировано задание: " >> io($logfile) if $DEBUG;
	"[$$]: ($task,$type,$offset,$length,$dataoffset)\n" >> io($logfile) if $DEBUG;
	$taskreq->enqueue($task,$type,$offset,$length,$dataoffset);
	$task++;
	# Закрываем обработчиков.
	if (($task>=$max_task)||($exit)) {
	    $exit=1;
	    print "Закрываем обработчиков.\n";
	    "[$$]: Закрываем обработчиков.\n" >> io($logfile) if $DEBUG;
	    $taskreq->enqueue(undef);
	}
    }
}
#-----------------------------------------------------------------------------
# Обработчики.
sub thread_worker { 
    print "Запуск обработчика.\n";
    "[$$]: Запуск обработчика.\n" >> io($logfile) if $DEBUG;
    my $self = threads->self(); 
    my $tid = $self->tid();
    while (defined (my $job=$taskreq->pending())) {
	# Ждем задание.
	print "Ждем задание: ";
	"[$$]: Ждем задание: " >> io($logfile) if $DEBUG;
	my ($task,$type,$offset,$length,$dataoffset)= $taskreq->dequeue;
	print "($task,$type,$offset,$length,$dataoffset)\n";
	"[$$]: ($task,$type,$offset,$length,$dataoffset)\n" >> io($logfile) if $DEBUG;
	my ($start_seconds, $start_microseconds) = gettimeofday; # Время старта операции.
	usleep (100); # Для тестирования.
	if($type){
#	    aio_read $fh,$offset,$length, $data,$dataoffset, $callback->($retval) # $dataoffset=0
#	    aio_read $fh, 0, $length_data, $contents, 0, sub {
#	    $_[0] == $length_data or die "short read: $!";
#    	    close $fh;
#	    print "Буфер создан, размер: ".$real_length_data."\n";
#	    };
	}else{
#	    aio_write $fh,$offset,$length, $data,$dataoffset, $callback->($retval)
#	    aio_read $fh, 7, 15, $buffer, 0, sub {
#		$_[0] > 0 or die "read error: $!";
#		print "read $_[0] bytes: <$buffer>\n";
#	    };
	}
	# Ждем завершения.
#	IO::AIO::flush;
	# Отправляем отчет.
	"[$$]: Отправляем отчет." >> io($logfile) if $DEBUG;
	my ($stop_seconds, $stop_microseconds) = gettimeofday; # Время завершения операции.
	$answerreq->enqueue($task,$type,$length,$start_seconds,$start_microseconds,$stop_seconds, $stop_microseconds);
	"[$$]: ($task,$type,$length,$start_seconds,$start_microseconds,$stop_seconds, $stop_microseconds)" >> io($logfile) if $DEBUG;
    }
    # Закрываем канал отчетов.
    "[$$]: Закрываем канал отчетов." >> io($logfile) if $DEBUG;
    $answerreq->enqueue(undef); 
    # Наверно этот вариант не подойдет и ориентировать стоит на колличество
    # обработчиков.
#    threads->exit();
}

#-----------------------------------------------------------------------------
# Создаём наш тестовый файл:
print "Создаём наш тестовый файл: $file\n";
"[$$]: Создаём наш тестовый файл: $file\n" >> io($logfile) if $DEBUG;
aio_open $file,IO::AIO::O_RDWR|IO::AIO::O_CREAT|IO::AIO::O_TRUNC|IO::AIO::O_NONBLOCK,0644,sub {
    $fh = shift or die "error while opening: $!";
};

# Запускаем контрллер.
print "Запускаем контроллер.\n";
"[$$]: Запускаем контроллер.\n" >> io($logfile) if $DEBUG;
my $boss = threads->new(&thread_boss);

# Запускаем обработчики.
print "Запускаем обработчики.\n";
"[$$]: Запускаем обработчики.\n" >> io($logfile) if $DEBUG;
for (1..$max_threads) {
    push @threads, threads->new(&thread_worker);
}

print "Ждем завершения контролёра.\n";
"[$$]: Ждем завершения контролёра.\n" >> io($logfile) if $DEBUG;
$boss->join(); # Ждем завершения контролёра.

# Закрываем наш файл
print "Закрываем и удаляем наш файл.\n";
"[$$]: Закрываем и удаляем наш файл.\n" >> io($logfile) if $DEBUG;
close $fh;
unlink $file;
#-----------------------------------------------------------------------------

# Как то обрабатываем и сохраняем результаты.

#-----------------------------------------------------------------------------
exit 0;

























