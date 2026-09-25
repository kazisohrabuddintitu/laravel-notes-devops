<?php

use App\Models\Note;
use App\Models\User;

test('guests are redirected to the login page', function () {
    $this->get(route('notes.index'))->assertRedirect(route('login'));
});

test('users only see their own notes', function () {
    $user = User::factory()->create();
    $mine = Note::factory()->for($user)->create();
    $theirs = Note::factory()->create();

    $this->actingAs($user)
        ->get(route('notes.index'))
        ->assertOk()
        ->assertInertia(fn ($page) => $page
            ->component('notes/index')
            ->has('notes', 1)
            ->where('notes.0.id', $mine->id)
        );
});

test('users can create a note', function () {
    $user = User::factory()->create();

    $this->actingAs($user)
        ->post(route('notes.store'), ['title' => 'Shopping', 'body' => 'Milk'])
        ->assertRedirect(route('notes.index'));

    expect($user->notes()->first())
        ->title->toBe('Shopping')
        ->body->toBe('Milk');
});

test('a note requires a title', function () {
    $user = User::factory()->create();

    $this->actingAs($user)
        ->post(route('notes.store'), ['title' => ''])
        ->assertSessionHasErrors('title');

    expect(Note::count())->toBe(0);
});

test('users can update their note', function () {
    $note = Note::factory()->create();

    $this->actingAs($note->user)
        ->put(route('notes.update', $note), ['title' => 'Updated', 'body' => null])
        ->assertRedirect(route('notes.index'));

    expect($note->fresh()->title)->toBe('Updated');
});

test('users can delete their note', function () {
    $note = Note::factory()->create();

    $this->actingAs($note->user)
        ->delete(route('notes.destroy', $note))
        ->assertRedirect(route('notes.index'));

    expect(Note::count())->toBe(0);
});

test('users cannot edit, update or delete notes of other users', function () {
    $note = Note::factory()->create();
    $otherUser = User::factory()->create();

    $this->actingAs($otherUser)->get(route('notes.edit', $note))->assertForbidden();
    $this->actingAs($otherUser)->put(route('notes.update', $note), ['title' => 'Hacked'])->assertForbidden();
    $this->actingAs($otherUser)->delete(route('notes.destroy', $note))->assertForbidden();

    expect($note->fresh()->title)->not->toBe('Hacked');
});
