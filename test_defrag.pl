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
my $length_data=1024*1024*1024; 	# Длина данных
my $real_length_data;			# То же.
my $taskreq=Thread::Queue::Any->new;
my $answerreq=Thread::Queue::Any->new;
my @threads;

my $max_threads=10; 	# Колличество обработчиков.
my $max_task=100;	# Максимальное колличество заданий.
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
    my $self = threads->self(); 
    my $tid = $self->tid();
    "[$$]: Старт контролёра, tid=$tid\n" >> io($logfile) if $DEBUG;
    my $task=0; 	# Номер задания.
    my $type;		# Тип задания чтение или запись.
    my $offset;		# Смещение от начала ($content).
    my $length;		# Длина записи.
    my $dataoffset;	# Смещение от начала записываемого файла.
    my $exit=0;		# Условие выхода ( 1 - выход). 
    my $all;		# Здесь будут результаты.
    $all->{'file_size'}=0;					# Можно подсчетать.
    $all->{'free_space'}=$all_space-$all->{'file_size'};	# Можно подсчитать.
    $all->{'count'}=0;	# Колличество полученных отчетов.
    while (not $exit) {
        "[$$]".Dumper($all) >> io($logfile) if $DEBUG;
	next if $exit;
	# Не ждем результаты.
	"[$$]: Не ждём результат\n" >> io($logfile) if $DEBUG;
	my ($old_task,$old_type,$old_length,$start_seconds,$start_microseconds,$stop_seconds, $stop_microseconds)=$answerreq->dequeue_dontwait;
	if (defined $old_task) {
	    "[$$]: Есть результат:\n" >> io($logfile) if $DEBUG;
	    "[$$]: ($old_task,$old_type,$old_length,$start_seconds,$start_microseconds,$stop_seconds, $stop_microseconds)\n" >> io($logfile) if $DEBUG;
	    # Обрабатываем результаты.
	    $all->{'count'}++;
	    $all->{$old_task}{'type'}=$old_type;
	    unless ($old_type) {
		$all->{$old_task}{'type_sim'}="rd";
	    } else {
		$all->{$old_task}{'type_sim'}="rw";
	    }
	    $all->{$old_task}{'length'}=$old_length;
	    $all->{$old_task}{'length_Mb'}=sprintf("%.2f",$old_length/1024/0124);
	    $all->{$old_task}{'start_seconds'}=$start_seconds;
	    $all->{$old_task}{'start_microseconds'}=$start_microseconds;
	    $all->{$old_task}{'stop_seconds'}=$stop_seconds;
	    $all->{$old_task}{'stop_microseconds'}=$stop_microseconds;
	    $all->{$old_task}{'time_diff'}=tv_interval ([$start_seconds,$start_microseconds],[$stop_seconds,$stop_microseconds]);
	    $all->{$old_task}{'speed'}=$old_length/$all->{$old_task}{'time_diff'};
	    $all->{$old_task}{'speed_Mb'}=sprintf("%.2f",$all->{$old_task}{'speed'}/1024/0124);
	    $all->{'file_size'}+=$old_length if $old_type; 	# Если запись добавляем.
	    $all->{'file_size_Mb'}=sprintf("%.2f",$all->{'file_size'}/1024/1024);
	    $all->{'free_space'}=$all_space-$all->{'file_size'};# Свободное место что осталось.
	    $all->{'free_space_Mb'}=sprintf("%.2f",$all->{'free_space'}/1024/1024);
	    $all->{'free_space_pr'}=sprintf("%.2f",$all->{'free_space'}*100/$all_space);
	    "[$$]".Dumper($all) >> io($logfile) if $DEBUG;
	    print	"Task: ".$old_task.
			" type: ".$all->{$old_task}{'type_sim'}.
			" length: ".$all->{$old_task}{'length_Mb'}.
			"Mb speed : ".$all->{$old_task}{'speed_Mb'}.
			"Mb/c file size: ".$all->{'file_size_Mb'}.
			"Mb free space :".$all->{'free_space_pr'}.
			"% free space: ".$all->{'free_space_Mb'}."Mb \n";
	} else {
	    "[$$]: нет результата.\n" >> io($logfile) if $DEBUG;
	    my $job=$answerreq->pending();
	    if ($job==$max_threads) {
		"[$$]: Нет результатов и есть задания для всех обработчиков - пропускаем ход.\n" >> io($logfile) if $DEBUG;
		usleep (10);
		next; # Если нет результатов и есть задания для всех обработчиков - пропускаем ход.
	    }
	}
	    "[$$]: Ставим задания.\n" >> io($logfile) if $DEBUG;
	    # Ставим задания.
	    $type=int rand 2; 					# 0 - чтение, 1 - запись.
	    unless ($type){
		"[$$]: Выпало чтение.\n" >> io($logfile) if $DEBUG;
		next unless $all->{'file_size'}; # Если читать нечего пропускаем ход.
		$offset=int rand $all->{'file_size'};
		$length=int rand ($all->{'file_size'}-$offset);
		# Чтение (не может быть за пределами файла.)				
		$dataoffset=0;					# 0 так как чтение.
	    }else{
	    	"[$$]: Выпала запись.\n" >> io($logfile) if $DEBUG;
		$offset=int rand $real_length_data; 		# 0 - $real_length_data
		# Длина записи неможет быть больше блока данных.
		$length=int rand ($real_length_data-$offset); 	# 0 - ($real_length_data-$offset)
		"[$$] Длина записи первичная: $length\n" >> io($logfile) if $DEBUG;
		# Запись.
	        # Возможны два режима:
		# 1) Диск еще не забит полностью и мы дописываем.
	        # 2) Диск забит полностью и пишем в середину.
		unless ($all->{'free_space'}) {
		    # Свободного мета нет - пишем в середину.
		    "[$$]: Свободного мета нет - пишем в середину.\n" >> io($logfile) if $DEBUG;
	    	    $dataoffset=int rand ($all->{'file_size'}); 	# 0 - file_size
	    	    $dataoffset=$all->{'file_size'} if ($dataoffset > $all->{'file_size'});
	    	    $length=$all->{'file_size'}-$dataoffset if ($length > $all->{'file_size'}-$dataoffset);
	        }else{
	            # Свободное мето есть.
	            "[$$]".Dumper($all) >> io($logfile) if $DEBUG;
	            "[$$]: Свободное мето есть.\n" >> io($logfile) if $DEBUG;
	            # $dataoffset < $all->{'file_size'}+$all->{'free_space'} 
	            # $dataoffset+$length < $all->{'free_space'}
		    $dataoffset=int rand($all->{'file_size'});
		    "[$$]: Смещение от начала файла: $dataoffset.\n" >> io($logfile) if $DEBUG;
		    $length=$all->{'file_size'}+$all->{'free_space'} if ($dataoffset+$length > $all->{'file_size'}+$all->{'free_space'});
		    "[$$] Длина записи после проверок: $length\n" >> io($logfile) if $DEBUG;
		    		    
		}
	    }	
	# Мы сюда не дойдём если у кажого обработчика есть задание.
	"[$$]: Сформировано задание:\n" >> io($logfile) if $DEBUG;
	"[$$]: ($task,$type,$offset,$length,$dataoffset)\n" >> io($logfile) if $DEBUG;
	$taskreq->enqueue($task,$type,$offset,$length,$dataoffset);
	$task++;
	# Закрываем обработчиков.
	if (($all->{'count'}>=$max_task)||($exit)) {
	    $exit=1;
	    "[$$]: Закрываем обработчиков.\n" >> io($logfile) if $DEBUG;
	    $taskreq->enqueue(undef,undef,undef,undef,undef) for (1..$max_threads);
	    "[$$] Закрываем контролёра.\n" >> io($logfile) if $DEBUG;
	    "[$$] Нужно организовать вывод результатов.\n" >> io($logfile) if $DEBUG;
	    "[$$]:\n".Dumper($all) >> io($logfile) if $DEBUG;
	}
    }
}
#-----------------------------------------------------------------------------
# Обработчики.
sub thread_worker { 
    my $i=shift;
    my $self = threads->self(); 
    my $tid = $self->tid();
    "[$$]: Запуск обработчика, tid=$tid i=$i\n" >> io($logfile) if $DEBUG;
    my $exit=0;		# Условие выхода ( 1 - выход). 
    while (not $exit) {
	# Ждем задание.
	"[$$]: Ждем задание:\n" >> io($logfile) if $DEBUG;
	my ($task,$type,$offset,$length,$dataoffset)= $taskreq->dequeue;
	if (defined $task) {
#	    usleep(100);
	    "[$$]: ($task,$type,$offset,$length,$dataoffset)\n" >> io($logfile) if $DEBUG;
	    my ($start_seconds, $start_microseconds) = gettimeofday; # Время старта операции.
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
#	    IO::AIO::flush;
	    # Отправляем отчет.
	    "[$$]: Отправляем отчет.\n" >> io($logfile) if $DEBUG;
	    my ($stop_seconds, $stop_microseconds) = gettimeofday; # Время завершения операции.
	    $answerreq->enqueue($task,$type,$length,$start_seconds,$start_microseconds,$stop_seconds, $stop_microseconds);
	    "[$$]: ($task,$type,$length,$start_seconds,$start_microseconds,$stop_seconds, $stop_microseconds)\n" >> io($logfile) if $DEBUG;	
	} else {
	    "[$$] Закрывается обработчик: $i\n" >> io($logfile) if $DEBUG;
	    $exit=1;
    	}
    }
}

#-----------------------------------------------------------------------------
# Создаём наш тестовый файл:
"[$$]: Создаём наш тестовый файл: $file\n" >> io($logfile) if $DEBUG;
aio_open $file,IO::AIO::O_RDWR|IO::AIO::O_CREAT|IO::AIO::O_TRUNC|IO::AIO::O_NONBLOCK,0644,sub {
    $fh = shift or die "error while opening: $!";
    close $fh;
};

# Запускаем контрллер.
"[$$]: Запускаем контроллер.\n" >> io($logfile) if $DEBUG;
my $boss = threads->new(sub{\&thread_boss()});

# Запускаем обработчики.
"[$$]: Запускаем обработчики.\n" >> io($logfile) if $DEBUG;
for (my $i=1;$i<=$max_threads;$i++) {
    push @threads, threads->new(sub{\&thread_worker($i)});
}

"[$$]: Ждем завершения обработчиков.\n" >> io($logfile) if $DEBUG;
foreach my $thread (@threads) {
    $thread->join();
}

"[$$]: Ждем завершения контролёра.\n" >> io($logfile) if $DEBUG;
$boss->join(); # Ждем завершения контролёра.


# Закрываем наш файл
"[$$]: Закрываем и удаляем наш файл.\n" >> io($logfile) if $DEBUG;
unlink $file;

my @err=threads->list(threads::all);
"[$$]:\n".Dumper(@err) >> io($logfile) if $DEBUG;
#-----------------------------------------------------------------------------
"[$$]: Обработка результатов.\n" >> io($logfile) if $DEBUG;

# Как то обрабатываем и сохраняем результаты.

#-----------------------------------------------------------------------------
exit 0;
#-----------------------------------------------------------------------------
