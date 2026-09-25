import { Form, Head, Link } from '@inertiajs/react';
import NoteController from '@/actions/App/Http/Controllers/NoteController';
import Heading from '@/components/heading';
import InputError from '@/components/input-error';
import { Button } from '@/components/ui/button';
import {
    Card,
    CardDescription,
    CardFooter,
    CardHeader,
    CardTitle,
} from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { index } from '@/routes/notes';

type Note = {
    id: number;
    title: string;
    body: string | null;
    updated_at: string;
};

export default function NotesIndex({ notes }: { notes: Note[] }) {
    return (
        <>
            <Head title="Notes" />

            <div className="flex h-full flex-1 flex-col gap-8 p-4">
                <section className="max-w-xl space-y-6">
                    <Heading
                        title="Notes"
                        description="Write something down so you don't forget it"
                    />

                    <Form
                        {...NoteController.store.form()}
                        resetOnSuccess
                        options={{ preserveScroll: true }}
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
                                        placeholder="Note title"
                                    />
                                    <InputError message={errors.title} />
                                </div>

                                <div className="grid gap-2">
                                    <Label htmlFor="body">Body</Label>
                                    <textarea
                                        id="body"
                                        name="body"
                                        rows={4}
                                        placeholder="Write your note..."
                                        className="w-full rounded-md border border-input bg-transparent px-3 py-2 text-base shadow-xs outline-none placeholder:text-muted-foreground focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 md:text-sm"
                                    />
                                    <InputError message={errors.body} />
                                </div>

                                <Button
                                    disabled={processing}
                                    data-test="create-note-button"
                                >
                                    Add note
                                </Button>
                            </>
                        )}
                    </Form>
                </section>

                <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
                    {notes.length === 0 && (
                        <p className="text-sm text-muted-foreground">
                            No notes yet. Add your first one above.
                        </p>
                    )}

                    {notes.map((note) => (
                        <Card key={note.id}>
                            <CardHeader>
                                <CardTitle>{note.title}</CardTitle>
                                {note.body && (
                                    <CardDescription className="whitespace-pre-line">
                                        {note.body}
                                    </CardDescription>
                                )}
                            </CardHeader>

                            <CardFooter className="gap-2">
                                <Button variant="outline" size="sm" asChild>
                                    <Link href={NoteController.edit(note.id)}>
                                        Edit
                                    </Link>
                                </Button>

                                <Form
                                    {...NoteController.destroy.form(note.id)}
                                    options={{ preserveScroll: true }}
                                    onBefore={() =>
                                        confirm('Delete this note?')
                                    }
                                >
                                    {({ processing }) => (
                                        <Button
                                            variant="destructive"
                                            size="sm"
                                            disabled={processing}
                                        >
                                            Delete
                                        </Button>
                                    )}
                                </Form>
                            </CardFooter>
                        </Card>
                    ))}
                </section>
            </div>
        </>
    );
}

NotesIndex.layout = {
    breadcrumbs: [
        {
            title: 'Notes',
            href: index(),
        },
    ],
};
