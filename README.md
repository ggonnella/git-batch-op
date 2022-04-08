GitBatchOp project is a Bash script which allows to run git repository
operations on a group of repositories.

# Installation

To install GitBatchOp, the repository main directory must be in path so that
the ``g`` script is found.
Auto-completion can be enabled in Bash by sourcing the provided
auto-completion script ``g-completion.bash``, e.g. in the Bash startup files.

# Configuration file

The location of all git repositories, as well as the repository groups
configurations are stored in a configuration file
(default location: ``$HOME/.config/ggscripts/git_repository_locations``).
Empty and comment lines in this file are ignored.

Each repository belong to a group; depending on the group
different operations are allowed and performed by the scripts.
Lines starting with ! are group and groupsets tab-separated declaration lines.

In the group declaration lines, the fields are:
- [``!``, ``group``] constant values
- group ID (format: like a C identifier)
- ``allow_up``: allow this group as a target for the up operation (values: "yes" or "no")

e.g.: ``!       group   gg      yes``

In groupset declaration lines, the fields are:
- [``!``, ``groupset``] constant values
- groupsetID (format: like a C identifier)
- group [group ...]: space separated list of group names
   to be included in the groupset
- ``allow_up``: allow this groupset as a target for the up operation (values: "yes" or "no")

e.g.: ``!       groupset        all     gg gg2 gg3       no``

Finally, the metadata of repositories, such as location in different systems is
stored. Each system is identified by the result of ``hostname`` or by the value
assigned to an env variable called ``$NETWORK``.

The fields for each repository metadata line:
- <groupID>: group ID to which to assign the repository
- server[,server2,...]: name of hosts for which a given location is given:
- <path>: path to the repository
- <name>: a short repo-ID; optional, but if not provided, then single-repo
operations will not be available

e.g.: ``gg      hostA,hostB,hostC  ~/notes notes``

# git up macro

The ``up`` macro, defined in ``git-up-macro`` can be added to the ``$HOME/.gitconfig``
git configuration file.

It defines an action ``git up``, which adds all modifications,
commits with the message "update" and pushes upstream.
If used as ``git up foo bar`` it uses the rest of the line as commit
message.
It should not be used in repositories where commit messages matter.
Thus the configuration file of git-batch-op (see below) allows to
specify that the ``up`` operation (when called using ``g``) is allowed
on specific group (and sets of groups) of repositories.

# Command line interface

In the following ``<target>`` is either a repository ID or a group ID
                    as defined in the configuration file.

- ``g st <target> [<target> ...]``: show the current status of all target repos
- ``g df <target> [<target> ...]``: show git diff with the HEAD for all target repos
- ``g lg <target> [<target> ...]``: show last commit log of all target repos
- ``g ls <target> [<target> ...]``: show the path to all target repos
- ``g up <repoID> commit msg``: commit and push changes in repo withID <repoID>;
                     using the specified commit msg
- ``g up <repoID>``: commit and push changes in repo withID <repoID>;
                     use "updated" as git commit msg
- ``$(g cd <repoID>): go to the path of repository with ID <repoID>
- ``g --conf``: open the configuration file in vim

