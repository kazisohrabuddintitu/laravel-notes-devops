<?php

namespace App\Http\Controllers;

use App\Http\Requests\NoteRequest;
use App\Models\Note;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Inertia\Inertia;
use Inertia\Response;

class NoteController extends Controller
{
    /**
     * Show the user's notes.
     */
    public function index(Request $request): Response
    {
        return Inertia::render('notes/index', [
            'notes' => $request->user()->notes()->latest()->get(['id', 'title', 'body', 'updated_at']),
        ]);
    }

    /**
     * Store a new note.
     */
    public function store(NoteRequest $request): RedirectResponse
    {
        $request->user()->notes()->create($request->validated());

        Inertia::flash('toast', ['type' => 'success', 'message' => __('Note created.')]);

        return to_route('notes.index');
    }

    /**
     * Show the form for editing a note.
     */
    public function edit(Note $note): Response
    {
        Gate::authorize('update', $note);

        return Inertia::render('notes/edit', [
            'note' => $note->only(['id', 'title', 'body']),
        ]);
    }

    /**
     * Update a note.
     */
    public function update(NoteRequest $request, Note $note): RedirectResponse
    {
        Gate::authorize('update', $note);

        $note->update($request->validated());

        Inertia::flash('toast', ['type' => 'success', 'message' => __('Note updated.')]);

        return to_route('notes.index');
    }

    /**
     * Delete a note.
     */
    public function destroy(Note $note): RedirectResponse
    {
        Gate::authorize('delete', $note);

        $note->delete();

        Inertia::flash('toast', ['type' => 'success', 'message' => __('Note deleted.')]);

        return to_route('notes.index');
    }
}
