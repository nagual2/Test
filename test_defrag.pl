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
my $data="/dev/random"; # $data="/dev/zero"; # Вариант с zero тест на SendForce2.
my $contents=""; 	# Переменная в которой будет храниться сгенеренные данные.
my $length_data=1024*1024; 	# Длина данных
my $real_length_data;		# То же.
my $taskreq=Thread::Queue::Any->new;
my $answerreq=Thread::Queue::Any->new;
my @threads;
my $all; 		# Здесь будут результаты.
my $max_threads=2; 	# Колличество обработчиков.
my $max_task=10;	# Максимальное колличество заданий.
my $all_space=1024*1024*1024*20; # Размер свободного места под тесты (должно измеряться).
#-----------------------------------------------------------------------------
aio_open $data, IO::AIO::O_RDONLY, 0, sub {
    my $fh = shift or die "error while opening: $!";
    aio_read $fh, 0, $length_data, $contents, 0, sub {
	$_[0] == $length_data or die "short read: $!";
 	close $fh;
 	$real_length_data=length($contents);
	print "Буфер создан, размер: ".$real_length_data."\n";
    };
};
# Ждем завершения.
IO::AIO::flush;
#-----------------------------------------------------------------------------
# Контроллёр.
sub thread_boss { 
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
	# Не ждем результаты.
	my ($old_task,$old_type,$old_length,$start_seconds,$start_microseconds,$stop_seconds, $stop_microseconds)=$answerreq->dequeue_dontwait;
	if (defined $old_task) {
	    # Обрабатываем результаты.
	    $all->{$old_task}{'type'}=$old_type;
	    $all->{$old_task}{'length'}=$old_length;
	    $all->{$old_task}{'start_seconds'}=$start_seconds;
	    $all->{$old_task}{'start_microseconds'}=$start_microseconds;
	    $all->{$old_task}{'stop_seconds'}=$stop_seconds;
	    $all->{$old_task}{'stop_microseconds'}=$stop_microseconds;
	    $all->{$old_task}{'time_diff'}=tv_interval $start_seconds $start_microseconds $stop_seconds $stop_microseconds;	    
	    $all->{$old_task}{'speed'}=$old_length/$all->{$old_task}{'time_diff'};
	    $all->{'file_size'}+=$old_length if $old_type; # Если запись добавляем.

	    # Ставим задания.
	    $type=int rand 2; 					# 0 - чтение, 1 - запись.
	    $offset=int rand $real_length_data; 		# 0 - $real_length_data
	    $length=int rand ($real_length_data-$offset); # 0 - ($real_length_data-$offset)	    
	    # Возможны два режима:
	    # 1) Диск еще не забит полностью и мы дописываем.
	    # 2) Диск забит полностью и пишем в середину.
	    $dataoffset=int rand ($all->{'file_size'}); # 0 - file_size
#	$text[int(rand($tsize))],	    

	} else {
	    if ($job==$max_threads) {
		usleep (10);
		next; # Если нет результатов и есть задания для всех обработчиков - пропускаем ход.
	    } else {
		# Ставим задания.
		$type=int rand 2; 				# 0 - чтение, 1 - запись.
	        $offset=int rand $real_length_data; 		# 0 - $real_length_data
		$length=int rand ($real_length_data-$offset); 	# 0 - ($real_length_data-$offset)
#		unless ($all->{'free_space'})
	        $dataoffset=int rand ($all->{'file_size'}); 	# 0 - file_size	    
	    }
	}
	# Мы сюда не дойдём если у кажого обработчика есть задание.
	$taskreq->enqueue($task,$type,$offset,$length,$dataoffset);
	$task++;	
	$taskreq->enqueue(undef) if (($task>=$max_task)||($exit));
    }
}
#-----------------------------------------------------------------------------
# Обработчики.
sub thread_worker { 
    my $self = threads->self(); 
    my $tid = $self->tid();
    while  ($taskreq->pending()) {
	# Ждем задание.
	my ($task,$type,$offset,$length,$dataoffset)= $taskreq->dequeue;
	my ($start_seconds, $start_microseconds) = gettimeofday; # Время старта операции.
	usleep (1000); # Для тестирования.

#    aio_write $fh,$offset,$length, $data,$dataoffset, $callback->($retval)
#    aio_read $fh, 7, 15, $buffer, 0, sub {
#	$_[0] > 0 or die "read error: $!";
#	print "read $_[0] bytes: <$buffer>\n";
#    };

	# Отправляем отчет.
	my ($stop_seconds, $stop_microseconds) = gettimeofday; # Время завершения операции.
	$answerreq->enqueue($task,$type,$length,$start_seconds,$start_microseconds,$stop_seconds, $stop_microseconds);
    }
    $answerreq->enqueue(undef); # Закрываем канал отчетов.
    # Наверно этот вариант не подойдет и ориентировать стоит на колличество
    # обработчиков.
}

#-----------------------------------------------------------------------------

#Запускаем контрллер.
my $boss = threads->new(&thread_boss); 

# Запускаем обработчики.
for (1..$max_threads) {
    push @threads, threads->new(&thread_worker);
}

$boss->join(); # Ждем завершения контролёра.

#-----------------------------------------------------------------------------

# Как то обрабатываем и сохраняем результаты.

#-----------------------------------------------------------------------------
exit 0;

























