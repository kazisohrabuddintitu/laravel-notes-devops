import { Form, Head, Link } from '@inertiajs/react';
import NoteController from '@/actions/App/Http/Controllers/NoteController';
import Heading from '@/components/heading';
import InputError from '@/components/input-error';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { index } from '@/routes/notes';

type Note = {
    id: number;
    title: string;
    body: string | null;
};

export default function NotesEdit({ note }: { note: Note }) {
    return (
        <>
            <Head title="Edit note" />

            <div className="max-w-xl space-y-6 p-4">
                <Heading title="Edit note" />

                <Form
                    {...NoteController.update.form(note.id)}
                    className="space-y-4"
                >
                    {({ processing, errors }) => (
                        <>
                            <div className="grid gap-2">
                                <Label htmlFor="title">Title</Label>
                                <Input
                                    id="title"
                                    name="title"
                                    required
                                    defaultValue={note.title}
                                />
                                <InputError message={errors.title} />
                            </div>

                            <div className="grid gap-2">
                                <Label htmlFor="body">Body</Label>
                                <textarea
                                    id="body"
                                    name="body"
                                    rows={6}
                                    defaultValue={note.body ?? ''}
                                    className="w-full rounded-md border border-input bg-transparent px-3 py-2 text-base shadow-xs outline-none placeholder:text-muted-foreground focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 md:text-sm"
                                />
                                <InputError message={errors.body} />
                            </div>

                            <div className="flex items-center gap-2">
                                <Button
                                    disabled={processing}
                                    data-test="update-note-button"
                                >
                                    Save
                                </Button>
                                <Button variant="ghost" asChild>
                                    <Link href={index()}>Cancel</Link>
                                </Button>
                            </div>
                        </>
                    )}
                </Form>
            </div>
        </>
    );
}

NotesEdit.layout = {
    breadcrumbs: [
        {
            title: 'Notes',
            href: index(),
        },
        {
            title: 'Edit',
            href: index(),
        },
    ],
};
