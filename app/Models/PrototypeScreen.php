<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

#[Fillable([
    'name',
    'slug',
    'figma_reference',
    'description',
    'endpoint',
    'tech',
    'order_column',
])]
class PrototypeScreen extends Model
{
    /** @use HasFactory<\Database\Factories\PrototypeScreenFactory> */
    use HasFactory;

    protected function casts(): array
    {
        return [
            'order_column' => 'integer',
        ];
    }

    /**
     * URL da captura real do protótipo em public/img/prototipos/.
     * O nome é percent-encoded porque os arquivos têm acentos e parênteses.
     */
    protected function imageUrl(): Attribute
    {
        return Attribute::get(fn (): string => asset(
            'img/prototipos/'.rawurlencode((string) $this->figma_reference)
        ));
    }

    /** Indica se o arquivo de captura existe no disco. */
    protected function hasImage(): Attribute
    {
        return Attribute::get(fn (): bool => filled($this->figma_reference)
            && file_exists(public_path('img/prototipos/'.$this->figma_reference)));
    }
}