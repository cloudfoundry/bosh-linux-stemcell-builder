# what do these do?

Repack helpers allow quick customization of stemcells. They are designed to be
used together to compose lightweight stemcell customization scripts.

# why is it useful?

We often want to customize stemcells in different ways. Much of the scripting
involved is fairly repetitive and so the differences are very minor. However,
the setup and teardown steps are very easy to get wrong and it can be
frustrating to iterate on those steps. By making it easy to customize a stemcell
in a variety of ways using composable scripts we are able to customize the
stemcell in various ways and remove some of the duplication which makes it
easier to create one-off stemcells for specific purposes.

# how can I write my own?

These scripts are designed to read from stdin and write to stdout the directory
names that they are working on.  For example, the run-in-chroot script assumes
that its input is a chroot directory and it will write out the same directory
when it finishes.  The unmount script takes the mountpoint via stdin and
operates on that mountpoint. So long as you conform to that interface you can
write another helper easily.

