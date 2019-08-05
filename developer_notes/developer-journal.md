# Developer (Steve's) journal

This is a journal of developer thoughts. It is not a change log (that is in git) or an issue list.

### 2019-08-05

Current workflow to change object names:

searchreplacefiles_shell('*.txt',upper('epochcontents'),upper('epochprobemap'))

(need to change .txt, .m, object* files typically)

filenamesearchreplace(pwd,{'epochcontents'},{'epochprobemap'},'deleteOriginals',1,'noOp',1,'recursive',1)

(need to set noOp to 0 to make it run)


### 2019-01-03

We had the kick-off meeting with Squishymedia today. 

I would like to understand a bit more about JSON databases: what is json hyper schema for example.

Is our best database implementation related to open-neuro, MongoDB Stitch, Google Firebase?

We wondered if the file reading could somehow be encapsulated in the database rather than as a separate entity?

### 2019-01-04

I need to keep making progress on our analysis of Arani's intracellular data. I will put development questions aside and just use the system for a few days.

I will keep working on the draft paper, but only 30 minutes/day

I will only fix small bugs in code and docs needed to propel work on intracellular data
