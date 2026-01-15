.PHONY: all build format edit demo clean

all: build

build:
	@echo "\n   🚨  COMPILING  🚨 \n"
	dune build src/maxflow.exe
	ls src/*.exe > /dev/null && ln -fs src/*.exe .

format:
	ocp-indent --inplace src/*

edit:
	code . -n

demo-flow: build
	mkdir -p result
	@echo "Running Ford-Fulkerson demo"
	./maxflow.exe flow graphs/graph7.txt 1 9 result/result-flowdemo result/result-flowdemo-svg
	@echo "Result stored in result/"

demo-scheduling: build
	mkdir -p result
	@echo "\n Running Airplane Scheduling demo \n"
	./maxflow.exe scheduling scheduling/schedule3.txt 9 result/result-schdemo result/result-schdemo-svg
	@echo "Result stored in result/"

clean:
	find -L . -name "*~" -delete
	rm -f *.exe
	dune clean
