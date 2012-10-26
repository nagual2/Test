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
# |========== = ------------ ER ============== --------------- == ------------
# |----------- ======== ------------------ ---- ER -------------- ============
# |================= ----- ================ =================== --------------
# |============ === ------------ ER = ============ = ----------- ========== ==
# |================== ==== -- ------------ ------------------------ ----- ----
# |____________________________________________________________________________> T (вермя)
#
# Где --- это чтение, а === это запись, ER -удаление блока из середины файла.
#
$ENV{'THREADS_SOCKET_UNIX'}=1;
use forks;
use strict;
use warnings;
use diagnostics;
use v5.14;
use Data::Dumper;
use Time::HiRes qw(gettimeofday tv_interval usleep);
use threads;
use Thread::Queue::Any;
use IO::All;
use IO::AIO;
my $file="/mnt/fs/test01";	# Имя файла для тестирования.
my $fh;				# Дескриптор файла тестирования.
my $data="/dev/random"; # $data="/dev/zero"; # Вариант с zero тест на SendForce2.
my $contents=""; 	# Переменная в которой будет храниться сгенеренные данные.
my $max_threads=1; 	# Колличество обработчиков.
my $max_task=1000;	# Максимальное колличество заданий.
my $free_mem=1024*1024*1024*2; 		# Всего 2Гб оперативной памяти (своп не считаем).
my $length_data=1024*1024*1024; 	# Длина данных для записи.
my $real_length_data;			# То же.
my $w_syze=1024*1024*100;		# Объём памяти зарезирвированный под каждый обработчик.
my $rezerv=($max_threads+1)*$w_syze;
# Каждый обработчик должен выделить объём памяти для чтения.
# Из расчета 2Гб всего - 1Гб для записи=1Гб
my $length_worker=int(($free_mem-$length_data-$rezerv)/$max_threads);
my $taskreq=Thread::Queue::Any->new;
my $answerreq=Thread::Queue::Any->new;
my @threads;
my $all_space=1024*1024*1024*6; # Размер свободного места на диске под тесты (должно измеряться).
my $logfile="./test_defrag.log";
my $DEBUG=1;
"[$$]: test_defrag.pl Start\n" > io($logfile) if $DEBUG;
print "Создадим буфер с данными.\n";
"[$$]: Создадим буфер с данными.\n" >> io($logfile) if $DEBUG;
#-----------------------------------------------------------------------------
$SIG{'KILL'} = sub { threads->exit(); };
#$SIG{PIPE}='IGNORE';
#$SIG{INT}='IGNORE';
IO::AIO::min_parallel $max_threads;
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
IO::AIO::poll while IO::AIO::nreqs;
if ($real_length_data<$length_data) {
    print "Мало памяти для тестирования.\n";
    "[$$]: Мало памяти для тестирования.\n" >> io($logfile) if $DEBUG;
    exit 0;
}
print "Длина буфера чтения: $length_worker\n";
"[$$]: Длина буфера чтения: $length_worker\n" >> io($logfile) if $DEBUG;
#-----------------------------------------------------------------------------
# Контроллёр.
sub thread_boss {
    my $self = threads->self();
    my $tid = $self->tid();
    IO::AIO::reinit; # Будем актуальный размер файла не расчитывать а смотреть.
    "[$$]: * Старт контролёра, tid=$tid\n" >> io($logfile) if $DEBUG;
    my $task=0; 	# Номер задания.
    my $type;		# Тип задания чтение или запись.
    my $offset;		# Смещение от начала файла.
    my $length;		# Длина записи.
    my $dataoffset;	# Смещение от начала блока данных.
    my $exit=0;		# Условие выхода ( 1 - выход).
    my $all;		# Здесь будут результаты.
    $all->{'file_size'}=0;					# Можно подсчетать.
    $all->{'free_space'}=$all_space-$all->{'file_size'};	# Можно подсчитать.
    $all->{'count'}=0;		# Колличество полученных отчетов.
    $all->{'count_start'}=0;	# Колличество поставленных заданий.
    $all->{'length_data_Mb'}=sprintf("%.2f",$real_length_data/1024/1024);
    while (not $exit) {
        "[$$] * ".Dumper($all) >> io($logfile) if ($DEBUG>1);
	# Не ждем результаты.
	"[$$]: * Не ждём результат\n" >> io($logfile) if ($DEBUG>1);
	my ($old_task,$old_type,$old_offset,$old_length,$start_seconds,$start_microseconds,$stop_seconds, $stop_microseconds)=$answerreq->dequeue_dontwait;
	if (defined $old_task) {
	    "[$$]: * Есть результат:\n" >> io($logfile) if $DEBUG;
	    "[$$]: * ($old_task,$old_type,$old_offset,$old_length,$start_seconds,$start_microseconds,$stop_seconds, $stop_microseconds)\n" >> io($logfile) if $DEBUG;
	    # Обрабатываем результаты.
	    $all->{'count_start'}--;
	    $all->{$old_task}{'count'}=$all->{'count'};
	    $all->{'count'}++;
	    $all->{$old_task}{'type'}=$old_type;
	    unless ($old_type) {
		$all->{$old_task}{'type_sim'}="rd";
	    } else {
		$all->{$old_task}{'type_sim'}="rw";
	    }
	    $all->{$old_task}{'offset'}=$old_offset;
	    $all->{$old_task}{'length'}=$old_length;
	    $all->{$old_task}{'length_Mb'}=sprintf("%.2f",$old_length/1024/1024);
	    $all->{$old_task}{'start_seconds'}=$start_seconds;
	    $all->{$old_task}{'start_microseconds'}=$start_microseconds;
	    $all->{$old_task}{'stop_seconds'}=$stop_seconds;
	    $all->{$old_task}{'stop_microseconds'}=$stop_microseconds;
	    $all->{$old_task}{'time_diff'}=tv_interval ([$start_seconds,$start_microseconds],[$stop_seconds,$stop_microseconds]);
	    $all->{$old_task}{'speed'}=$old_length/$all->{$old_task}{'time_diff'};
	    $all->{$old_task}{'speed_Mb'}=sprintf("%.2f",$all->{$old_task}{'speed'}/1024/0124);
	    # Если запись добавляем.
	    if (($old_type==1)&&($old_length+$old_offset > $all->{$old_task}{'file_size'})) {
		$all->{'file_size'}+=($old_length+$old_offset-$all->{$old_task}{'file_size'});
	    }
	    # Если стирание отнимаем.
	    if ($old_type==2){
		$all->{'file_size'}-=$old_length;
	    }
	    "[$$]: * Статистика $file:\n" >> io($logfile) if ($DEBUG>0);
	    "[$$]: #r Открываем файл: $file для чтения.\n" >> io($logfile) if $DEBUG;
	    aio_open $file,IO::AIO::O_RDONLY,0, sub { # |IO::AIO::O_NONBLOCK
	        my $fh = shift or die "error while opening: $!";
	        "[$$]: #r Файл: $file открыт\n" >> io($logfile) if $DEBUG;
	        my $rd;
		$rd = sub {
    		    my $done_cb = shift; # Итак воспользуеммя прелестями замыканий.
		    aio_statvfs $fh, sub {
#	       my $stats = $_[0] or die "statvfs: $!";
	    	    "[$$]: * ".Dumper($_[0]) >> io($logfile) if ($DEBUG>0);
	    	    undef $rd;
            	    $done_cb->();
		};
		$rd->(
    		    sub {
        	        aio_close $fh, sub {
            		    die "close error: $!" if $_[0] < 0;
            		    "[$$]: #r Файл: $file закрыт\n" >> io($logfile) if $DEBUG;
        		};
    		    }
		);
	    };
	    IO::AIO::poll while IO::AIO::nreqs; # Ждем завершения.
	    $all->{'file_size_Mb'}=sprintf("%.2f",$all->{'file_size'}/1024/1024);
	    $all->{'free_space'}=$all_space-$all->{'file_size'};# Свободное место что осталось.
	    $all->{'free_space_Mb'}=sprintf("%.2f",$all->{'free_space'}/1024/1024);
	    $all->{'free_space_pr'}=sprintf("%.2f",$all->{'free_space'}*100/$all_space);
	    "[$$] * ".Dumper($all) >> io($logfile) if ($DEBUG>1);
	    print	"Task: ".$old_task.
			" type: ".$all->{$old_task}{'type_sim'}.
			" length: ".$all->{$old_task}{'length_Mb'}.
			" Mb speed : ".$all->{$old_task}{'speed_Mb'}.
			" Mb/c file size: ".$all->{'file_size_Mb'}.
			" Mb free space :".$all->{'free_space_pr'}.
			" % free space: ".$all->{'free_space_Mb'}."Mb \n";
			"[$$]: * Task: ".$old_task.
			" type: ".$all->{$old_task}{'type_sim'}.
			" length: ".$all->{$old_task}{'length_Mb'}.
			" Mb speed : ".$all->{$old_task}{'speed_Mb'}.
			" Mb/c file size: ".$all->{'file_size_Mb'}.
			" Mb free space :".$all->{'free_space_pr'}.
			" % free space: ".$all->{'free_space_Mb'}."Mb \n" >> io($logfile) if $DEBUG;
	} else {
	    "[$$]: * Нет результата.\n" >> io($logfile) if ($DEBUG>1);
	    if ($all->{'count_start'}>=$max_threads) {
		"[$$]: * Нет результатов и есть задания для всех обработчиков - пропускаем ход.\n" >> io($logfile) if ($DEBUG>1);
		usleep (100);
		next; # Если нет результатов и есть задания для всех обработчиков - пропускаем ход.
	    }
	}
	    "[$$]: * Ставим задания.\n" >> io($logfile) if $DEBUG;
	    # Ставим задания.
	    $type=int rand 2; # 0 - чтение, 1 - запись, 2 - удаление.
	    unless ($type){
		"[$$]: * Выпало чтение.\n" >> io($logfile) if $DEBUG;
		next unless $all->{'file_size'}; # Если читать нечего пропускаем ход.
#		next;
		$offset=int rand $all->{'file_size'};
		# Наверно не стоит читать объём больший чем буфер ...
		# $length=int rand ($all->{'file_size'}-$offset);
		# блок чтения неможет выйти за ограничения памяти.
		$length=int rand ($length_worker);
		"[$$]: * Длина чтения первичная: $length\n" >> io($logfile) if $DEBUG;
		# Чтение (не может быть за пределами файла.)
		$length=$all->{'file_size'}-$offset if ($length >$all->{'file_size'}-$dataoffset);
		"[$$]: * Длина чтения после проверок: $length\n" >> io($logfile) if $DEBUG;
		$dataoffset=0;					# 0 так как чтение.
	    } elsif($type==1) {
	    	"[$$]: * Выпала запись.\n" >> io($logfile) if $DEBUG;
		$dataoffset=int rand $real_length_data; 		# 0 - $real_length_data
		"[$$]: * Смещение первичное: $dataoffset\n" >> io($logfile) if $DEBUG;
		# Длина записи неможет быть больше блока данных.
		$length=int rand ($real_length_data-$dataoffset); 	# 0 - ($real_length_data-$offset)
		"[$$]: * Длина записи первичная: $length\n" >> io($logfile) if $DEBUG;
		# Запись.
	        # Возможны два режима:
		# 1) Диск еще не забит полностью и мы дописываем.
	        # 2) Диск забит полностью и пишем в середину.
	        $offset=int rand ($all->{'file_size'}); 	# 0 - file_size
	    	"[$$]: * Смещение от начала файла: $offset.\n" >> io($logfile) if $DEBUG;
	    	# Файл не должен выйти за пределы свободного места на диске.
		my $length0=$length;
		$length0=$all->{'file_size'}+$all->{'free_space'}-$offset if ($offset+$length > $all->{'file_size'}+$all->{'free_space'});
		# Чтение данных не должно выйти за пределы блока памяти.
	    	$length=$real_length_data if ($length+$offset > $real_length_data);
	    	$length=$length0 if ($length0 < $length);
	    	"[$$]: * Длина записи после проверок: $length\n" >> io($logfile) if $DEBUG;
	    	"[$$]: * Смещение после проверок: $dataoffset\n" >> io($logfile) if $DEBUG;
	    } else {
		# Удаление.
	    	"[$$]: * Выпало удаление (нереализованно).\n" >> io($logfile) if $DEBUG;
	    	# Не будем удалять блок больше чем блок для записи.
	    	$length=int rand ($real_length_data);
	    	"[$$]: * Длина блока удаления первичная: $length\n" >> io($logfile) if $DEBUG;
	    	$offset=int rand ($all->{'file_size'});
	    	"[$$]: * Смещение от начала файла: $offset.\n" >> io($logfile) if $DEBUG;
	    }	
	# Мы сюда не дойдём если у кажого обработчика есть задание.
	"[$$]: * Сформировано задание:\n" >> io($logfile) if $DEBUG;
	"[$$]: * ($task,$type,$offset,$length,$dataoffset)\n" >> io($logfile) if $DEBUG;
	"[$$]: * Задание: $task\n" >> io($logfile) if $DEBUG;
	"[$$]: * Тип: $type\n" >> io($logfile) if $DEBUG;
	"[$$]: * Смещение от начала файла: $offset\n" >> io($logfile) if $DEBUG;
	"[$$]: * Длина обрабатываемого блока: $length\n" >> io($logfile) if $DEBUG;
	"[$$]: * Смещение от начала блока данных: $dataoffset\n" >> io($logfile) if $DEBUG;
	"[$$]: * Актуальный размер файла в этот момент: ".$all->{'file_size'}."\n" >> io($logfile) if $DEBUG;
	"[$$]: * Остаток свободного места в этот момент: ".$all->{'free_space'}."\n" >> io($logfile) if $DEBUG;
	$all->{$task}{'file_size'}=$all->{'file_size'}; # Размеер файла на момет начала операции.
	$taskreq->enqueue($task,$type,$offset,$length,$dataoffset);
	$task++;
	$all->{'count_start'}++;
	# Закрываем обработчиков.
	if (($all->{'count'}>=$max_task)||($exit)) {
	    $exit=1;
	    "[$$]: * Закрываем обработчиков.\n" >> io($logfile) if $DEBUG;
	    $taskreq->enqueue(undef,undef,undef,undef,undef) for (1..$max_threads);
	    "[$$]: * Закрываем контролёра.\n" >> io($logfile) if $DEBUG;
	    "[$$]: * Нужно организовать вывод результатов.\n" >> io($logfile) if $DEBUG;
	    "[$$]: * ".Dumper($all) >> io($logfile) if ($DEBUG>1);
	}
    }
    return $all;
}
#-----------------------------------------------------------------------------
# Обработчики.
sub thread_worker {
    my $i=shift;
    my $self = threads->self();
    my $tid = $self->tid();
    "[$$]: # Запуск обработчика, tid=$tid i=$i\n" >> io($logfile) if $DEBUG;
    my $exit=0;		# Условие выхода ( 1 - выход).
    my $data="";	# Сюда будем читать.
    # You might get around by not using IO::AIO before (or after) forking.
    IO::AIO::reinit;
    while (not $exit) {
	# Ждем задание.
	"[$$]: # Ждем задание:\n" >> io($logfile) if $DEBUG;
	my ($task,$type,$offset,$length,$dataoffset)= $taskreq->dequeue;
	if (defined $task) {
	    "[$$]: # ($task,$type,$offset,$length,$dataoffset)\n" >> io($logfile) if $DEBUG;
	    "[$$]: # Получено задание: $task\n" >> io($logfile) if $DEBUG;
	    "[$$]: # Тип: $type\n" >> io($logfile) if $DEBUG;
	    "[$$]: # Смещение от начала блока данных: $offset\n" >> io($logfile) if $DEBUG;
	    "[$$]: # Длина обрабатываемого блока: $length\n" >> io($logfile) if $DEBUG;
	    "[$$]: # Смещение от начала файла: $dataoffset\n" >> io($logfile) if $DEBUG;
	    unless($type){
	    	"[$$]: #r Открываем файл: $file для чтения.\n" >> io($logfile) if $DEBUG;
		aio_open $file,IO::AIO::O_RDONLY,0, sub { # |IO::AIO::O_NONBLOCK
		    my $fh = shift or die "error while opening: $!";
		    "[$$]: #r Файл: $file открыт\n" >> io($logfile) if $DEBUG;
		    my $red;
		    $red = sub { # Делаем замыкание.
    			my $done_cb = shift; # Итак воспользуеммя прелестями замыканий.
    			my ($start_seconds, $start_microseconds) = gettimeofday; # Время старта операции.
			my $offset_=$offset; # Делаем копии изменяемых переменных для замыкания, чтобы в отчете отдавать.
    			"[$$]: #r Читаем:\n" >> io($logfile) if $DEBUG;
    			"[$$]: #r ($offset,$length,$dataoffset)\n" >> io($logfile) if $DEBUG;
    			aio_read $fh, $offset, $length, $data, $dataoffset, sub {
        		    die "write error: $!" if $_[0] < 0;
        		    if ($_[0]) {
        			"[$$]: #r Что то прочитали, отправляем отчет.\n" >> io($logfile) if $DEBUG;
				my ($stop_seconds, $stop_microseconds) = gettimeofday; # Время завершения операции.
				$answerreq->enqueue($task,$type,$offset_,$_[0],$start_seconds,$start_microseconds,$stop_seconds, $stop_microseconds); # Отправляем отчет.
				"[$$]: #r ($task,$type,$offset_,".$_[0].",$start_seconds,$start_microseconds,$stop_seconds, $stop_microseconds)\n" >> io($logfile) if $DEBUG;
        			"[$$]: #r Читаем последующие части.\n" >> io($logfile) if $DEBUG;
        			$offset+=$_[0];
        			$dataoffset+=$_[0];
        			$length-=$_[0];
        			"[$$]: #r ($task,$type,$offset,$length,$dataoffset)\n" >> io($logfile) if $DEBUG;
				"[$$]: #r Тип: $type\n" >> io($logfile) if $DEBUG;
				"[$$]: #r Смещение от начала блока данных: $offset\n" >> io($logfile) if $DEBUG;
				"[$$]: #r Длина обрабатываемого блока: $length\n" >> io($logfile) if $DEBUG;
				"[$$]: #r Смещение от начала файла: $dataoffset\n" >> io($logfile) if $DEBUG;
            			$red->($done_cb); # Рекурсия.
        		    } else {
            			undef $red;
            			$done_cb->(); # Закрываем файл.
        		    }
        		};
        	    };
		    "[$$]: #r Прочитали буфер.\n" >> io($logfile) if $DEBUG;
		    $red->(
    			sub {
        		    aio_close $fh, sub {
            			die "close error: $!" if $_[0] < 0;
            			"[$$]: #r Файл: $file закрыт\n" >> io($logfile) if $DEBUG;
        		    };
    			}
		    );
		};
		$data=""; # undef нельзя, будет варнинг.
	    } elsif($type==1) {
		"[$$]: #w Открываем файл: $file для записи.\n" >> io($logfile) if $DEBUG;
		aio_open $file,IO::AIO::O_WRONLY,0, sub { # |IO::AIO::O_NONBLOCK
		    my $fh = shift or die "error while opening: $!";
		    "[$$]: #w Файл: $file открыт\n" >> io($logfile) if $DEBUG;
		    my $wtr;
		    $wtr = sub {
    			my $done_cb = shift; # Итак воспользуеммя прелестями замыканий.
    			my ($start_seconds, $start_microseconds) = gettimeofday; # Время старта операции.
			my $offset_=$offset; # Делаем копии изменяемых переменных для замыкания, чтобы в отчете отдавать.
    			"[$$]: #w Пишем:\n" >> io($logfile) if $DEBUG;
    			"[$$]: #w ($offset,$length,$dataoffset)\n" >> io($logfile) if $DEBUG;
			aio_write $fh,$offset,$length, $contents,$dataoffset, sub {
        		    die "write error: $!" if $_[0] < 0;
        		    if ($_[0]) {
        			"[$$]: #w Что то записали, отправляем отчет.\n" >> io($logfile) if $DEBUG;
				my ($stop_seconds, $stop_microseconds) = gettimeofday; # Время завершения операции.
				$answerreq->enqueue($task,$type,$offset_,$_[0],$start_seconds,$start_microseconds,$stop_seconds, $stop_microseconds); # Отправляем отчет.
				"[$$]: #w ($task,$type,$offset_,".$_[0].",$start_seconds,$start_microseconds,$stop_seconds, $stop_microseconds)\n" >> io($logfile) if $DEBUG;
        		        "[$$]: #w Пишем последующие части.\n" >> io($logfile) if $DEBUG;
        		        $offset+=$_[0];
        			$dataoffset+=$_[0];
        			$length-=$_[0];
        		        "[$$]: #w ($task,$type,$offset,$length,$dataoffset)\n" >> io($logfile) if $DEBUG;
				"[$$]: #w Тип: $type\n" >> io($logfile) if $DEBUG;
				"[$$]: #w Смещение от начала блока данных: $offset\n" >> io($logfile) if $DEBUG;
			        "[$$]: #w Длина обрабатываемого блока: $length\n" >> io($logfile) if $DEBUG;
				"[$$]: #w Смещение от начала файла: $dataoffset\n" >> io($logfile) if $DEBUG;
            			$wtr->($done_cb);
        		    } else {
            			undef $wtr;
            			$done_cb->();
        		    }
			};
		    };
		    "[$$]: #w Записали буфер.\n" >> io($logfile) if $DEBUG;
		    $wtr->(
    			sub {
        		    aio_close $fh, sub {
            			die "close error: $!" if $_[0] < 0;
            			"[$$]: #w Файл: $file закрыт\n" >> io($logfile) if $DEBUG;
        		    };
    			}
		    );
		};
	    } else {
		# тут удаление блока.
	    }
	    IO::AIO::poll while IO::AIO::nreqs; # Ждем завершения.
	} else {
	    "[$$]: # Закрывается обработчик: $i\n" >> io($logfile) if $DEBUG;
	    $exit=1;
    	}
    }
}

#-----------------------------------------------------------------------------
# Создаём наш тестовый файл.
"[$$]: Создаём наш тестовый файл: $file\n" >> io($logfile) if $DEBUG;
aio_open $file,IO::AIO::O_RDWR|IO::AIO::O_CREAT|IO::AIO::O_TRUNC,0644,sub {
    my $fh = shift or die "error while opening: $!";
    close $fh;
};
IO::AIO::poll while IO::AIO::nreqs;

# Запускаем контрллер.
"[$$]: Запускаем контроллер.\n" >> io($logfile) if $DEBUG;
my $boss = threads->new(sub{ return my $tmp=\&thread_boss()});

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
my $result=$boss->join(); # Ждем завершения контролёра.

# Закрываем наш файл
"[$$]: Закрываем и удаляем наш файл.\n" >> io($logfile) if $DEBUG;
unlink $file;

my @err=threads->list(threads::all);
"[$$]:\n".Dumper(@err) >> io($logfile) if $DEBUG;
#-----------------------------------------------------------------------------
"[$$]: Обработка результатов.\n" >> io($logfile) if $DEBUG;
"[$$]:\n".Dumper($result) >> io($logfile) if $DEBUG;
# Как то обрабатываем и сохраняем результаты.
#-----------------------------------------------------------------------------
exit 0;
#-----------------------------------------------------------------------------