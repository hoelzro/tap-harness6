use TAP::Parser;
use TAP::Formatter;

class TAP::Harness {
	role SourceHandler {
		method can-handle {...};
		method make-async-source {...};
		method make-async-parser(Any :$name, :@handlers, Promise :$bailout) {
			self.make-async-source($name).make-parser(:@handlers :$bailout);
		}
	}
	class SourceHandler::Perl6 does SourceHandler {
		method can-handle($filename) {
			return True;
		}
		method make-async-source($name) {
			return TAP::Parser::Async::Source::Proc.new(:$name, :path($*EXECUTABLE), :args([$name]));
		}
	}

	has SourceHandler @.handlers = SourceHandler::Perl6.new();
	has Any @.sources;
	has TAP::Formatter:T $.formatter-class = TAP::Formatter::Console;

	class Run {
		has Promise $.done;
		has Promise $!kill;
		method kill(Any $reason = True) {
			$!kill.keep($reason) = Promise.new;
		}
		method result() {
			return $!done.result;
		}
	}

	method run(Int :$parallel = 2, TAP::Formatter :$formatter = $!formatter-class.new(:$parallel, :names(@.sources))) {
		my @working;
		my $kill = Promise.new;
		my $aggregator = TAP::Aggregator.new();
		my $done = start {
			for @!sources -> $name {
				last if $kill;
				my $session = $formatter.open-test($name);
				my $parser = @!handlers.max(*.can-handle($name)).make-async-parser(:$name, :handlers([$session]), :$kill);
				@working.push({ :$parser, :$session, :done($parser.done) });
				next if @working < $parallel;
				await Promise.anyof(@working.map(*.<done>), $kill);
				reap-finished();
			}
			await Promise.anyof(Promise.allof(@working.map(*.<done>)), $kill) if @working && not $kill;
			reap-finished();
			if ($kill) {
				.kill for @working;
			}
			$aggregator;
		};
		sub reap-finished() {
			my @new-working;
			for @working -> $current {
				if $current<done> {
					$aggregator.add-result($current<parser>.result);
					$current<session>.close-test($current<parser>.result);
				}
				else {
					@new-working.push($current);
				}
			}
			@working = @new-working;
		}
		return Run.new(:$done, :$kill);
	}
}
